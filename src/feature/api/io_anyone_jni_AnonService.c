/* Copyright (c) 2019, Matthew Finkel.
 * Copyright (c) 2019, Hans-Christoph Steiner.
 * Copyright (c) 2007-2019, The Tor Project, Inc. */
/* See LICENSE for licensing information */

#include "tor_api.h"
#include "io_anyone_jni_AnonService.h"
#include "orconfig.h"
#include "lib/malloc/malloc.h"

#include <jni.h>
#include <stdbool.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#ifdef HAVE_SYS_UN_H
#include <sys/socket.h>
#include <sys/un.h>
#endif

#ifdef __ANDROID__
#include <android/log.h>
#define fprintf(ignored, ...)                                           \
  __android_log_print(ANDROID_LOG_ERROR, "Anon-api", ##__VA_ARGS__)
#endif // __ANDROID__

/* with JNI, unused parameters are inevitable, suppress the warnings */
#define UNUSED(x) (void)(x)

static char **argv = NULL;
static int argc = 0;

static jfieldID
GetConfigurationFieldID(JNIEnv *env, jclass anonApiClass)
{
  return (*env)->GetFieldID(env, anonApiClass, "anonConfiguration", "J");
}

static jlong
GetConfigurationObject(JNIEnv *env, jobject thisObj)
{
  jclass anonApiClass = (*env)->GetObjectClass(env, thisObj);
  if (anonApiClass == NULL) {
    fprintf(stderr, "GetObjectClass returned NULL\n");
    return 0;
  }

  jfieldID anonConfigurationField = GetConfigurationFieldID(env, anonApiClass);
  if (anonConfigurationField == NULL) {
    fprintf(stderr, "The fieldID is NULL\n");
    return 0;
  }

  return (*env)->GetLongField(env, thisObj, anonConfigurationField);
}

static bool
SetConfiguration(JNIEnv *env, jobject thisObj,
                 const tor_main_configuration_t* anonConfiguration)
{
  jclass anonApiClass = (*env)->GetObjectClass(env, thisObj);
  if (anonApiClass == NULL) {
    return false;
  }

  jfieldID anonConfigurationField = GetConfigurationFieldID(env, anonApiClass);
  if (anonConfigurationField == NULL) {
    return false;
  }

  jlong cfg = (jlong) anonConfiguration;

  (*env)->SetLongField(env, thisObj, anonConfigurationField, cfg);
  return true;
}

static tor_main_configuration_t*
GetConfiguration(JNIEnv *env, jobject thisObj)
{
  jlong anonConfiguration = GetConfigurationObject(env, thisObj);
  if (anonConfiguration == 0) {
    fprintf(stderr, "The long is 0\n");
    return NULL;
  }

  return (tor_main_configuration_t *) anonConfiguration;
}

static jfieldID
GetControlSocketFieldID(JNIEnv * const env, jclass anonApiClass)
{
  return (*env)->GetFieldID(env, anonApiClass, "anonControlFd", "I");
}

static bool
SetControlSocket(JNIEnv *env, jobject thisObj, int socket)
{
  jclass anonApiClass = (*env)->GetObjectClass(env, thisObj);
  if (anonApiClass == NULL) {
    fprintf(stderr, "SetControlSocket: GetObjectClass returned NULL\n");
    return false;
  }

  jfieldID controlFieldId = GetControlSocketFieldID(env, anonApiClass);

  (*env)->SetIntField(env, thisObj, controlFieldId, socket);
  return true;
}

static bool
CreateAnonConfiguration(JNIEnv *env, jobject thisObj)
{
  jlong anonConfiguration = GetConfigurationObject(env, thisObj);
  if (anonConfiguration == 0) {
    return false;
  }

  tor_main_configuration_t *anon_config = tor_main_configuration_new();
  if (anon_config == NULL) {
    fprintf(stderr,
            "Allocating and creating a new configuration structure failed.\n");
    return false;
  }

  if (!SetConfiguration(env, thisObj, anon_config)) {
    tor_main_configuration_free(anon_config);
    return false;
  }

  return true;
}

static bool
SetCommandLine(JNIEnv *env, jobject thisObj, jobjectArray arrArgv)
{
  tor_main_configuration_t *cfg = GetConfiguration(env, thisObj);
  if (cfg == NULL) {
    fprintf(stderr, "SetCommandLine: The Anon configuration is NULL!\n");
    return -1;
  }

  jsize arrArgvLen = (*env)->GetArrayLength(env, arrArgv);
  if (arrArgvLen > (INT_MAX-1)) {
    fprintf(stderr, "Too many args\n");
    return false;
  }

  argc = (int) arrArgvLen;
  argv = (char**) tor_malloc(argc * sizeof(char*));
  if (argv == NULL) {
    return false;
  }

  for (jsize i=0; i<argc; i++) {
    jobject objElm = (*env)->GetObjectArrayElement(env, arrArgv, i);
    jstring argElm = (jstring) objElm;
    const char *arg = (*env)->GetStringUTFChars(env, argElm, NULL);
    argv[i] = strdup(arg);
  }

  if (tor_main_configuration_set_command_line(cfg, argc, argv)) {
    fprintf(stderr, "Setting the command line config failed\n");
    return false;
  }
  return true;
}

static int
SetupControlSocket(JNIEnv *env, jobject thisObj)
{
  jclass anonApiClass = (*env)->GetObjectClass(env, thisObj);
  if (anonApiClass == NULL) {
    fprintf(stderr, "SetupControlSocket: GetObjectClass returned NULL\n");
    return false;
  }

  tor_main_configuration_t *cfg = GetConfiguration(env, thisObj);
  if (cfg == NULL) {
    fprintf(stderr, "SetupControlSocket: The Anon configuration is NULL!\n");
    return false;
  }

  tor_control_socket_t tcs = tor_main_configuration_setup_control_socket(cfg);
  fcntl(tcs, F_SETFL, O_NONBLOCK);
  SetControlSocket(env, thisObj, tcs);
  return true;
}

static int
RunMain(JNIEnv *env, jobject thisObj)
{
  tor_main_configuration_t *cfg = GetConfiguration(env, thisObj);
  if (cfg == NULL) {
    fprintf(stderr, "RunMain: The Anon configuration is NULL!\n");
    return -1;
  }

  int rv = tor_run_main(cfg);
  if (rv != 0) {
    fprintf(stderr, "Anon returned with an error\n");
  } else {
    printf("Anon returned successfully\n");
  }
  return rv;
}

JNIEXPORT jboolean JNICALL
Java_io_anyone_jni_AnonService_createAnonConfiguration
(JNIEnv *env, jobject thisObj)
{
  return CreateAnonConfiguration(env, thisObj);
}

JNIEXPORT jboolean JNICALL
Java_io_anyone_jni_AnonService_mainConfigurationSetCommandLine
(JNIEnv *env, jobject thisObj, jobjectArray arrArgv)
{
  return SetCommandLine(env, thisObj, arrArgv);
}

JNIEXPORT jboolean JNICALL
Java_io_anyone_jni_AnonService_mainConfigurationSetupControlSocket
(JNIEnv *env, jobject thisObj)
{
  return SetupControlSocket(env, thisObj);
}

JNIEXPORT void JNICALL
Java_io_anyone_jni_AnonService_mainConfigurationFree
(JNIEnv *env, jobject thisObj)
{
  tor_main_configuration_t *cfg = GetConfiguration(env, thisObj);
  if (cfg == NULL) {
    fprintf(stderr, "ConfigurationFree: The Anon configuration is NULL!\n");
    return;
  }
  unset_owning_controller_socket(cfg);
  tor_main_configuration_free(cfg);
}

JNIEXPORT jstring JNICALL
Java_io_anyone_jni_AnonService_apiGetProviderVersion
(JNIEnv *env, jobject _ignore)
{
  UNUSED(_ignore);
  return (*env)->NewStringUTF(env, tor_api_get_provider_version());
}

JNIEXPORT jint JNICALL
Java_io_anyone_jni_AnonService_runMain
(JNIEnv *env, jobject thisObj)
{
  return RunMain(env, thisObj);
}

JNIEXPORT void JNICALL
Java_io_anyone_jni_AnonService_freeAll
(JNIEnv *env, jobject _ignore)
{
  UNUSED(env);
  UNUSED(_ignore);
  tor_free_all(0);
}
