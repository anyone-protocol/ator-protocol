/* Copyright (c) 2019, Matthew Finkel.
 * Copyright (c) 2019, Hans-Christoph Steiner.
 * Copyright (c) 2007-2019, The Tor Project, Inc. */
/* See LICENSE for licensing information */

#ifndef IO_ANYONE_JNI_ANONSERVICE_H
#define IO_ANYONE_JNI_ANONSERVICE_H

#include <jni.h>

/*
 * Class:     io_anyone_jni_AnonService
 * Method:    createAnonConfiguration
 * Signature: ()Z
 */
JNIEXPORT jboolean JNICALL
Java_io_anyone_jni_AnonService_createAnonConfiguration
(JNIEnv *, jobject);

/*
 * Class:     io_anyone_jni_AnonService
 * Method:    mainConfigurationSetCommandLine
 * Signature: ([Ljava/lang/String;)Z
 */
JNIEXPORT jboolean JNICALL
Java_io_anyone_jni_AnonService_mainConfigurationSetCommandLine
(JNIEnv *, jobject, jobjectArray);

/*
 * Class:     io_anyone_jni_AnonService
 * Method:    mainConfigurationSetupControlSocket
 * Signature: ()Z
 */
JNIEXPORT jboolean JNICALL
Java_io_anyone_jni_AnonService_mainConfigurationSetupControlSocket
(JNIEnv *, jobject);

/*
 * Class:     io_anyone_jni_AnonService
 * Method:    mainConfigurationFree
 * Signature: ()V
 */
JNIEXPORT void JNICALL
Java_io_anyone_jni_AnonService_mainConfigurationFree
(JNIEnv *, jobject);

/*
 * Class:     io_anyone_jni_AnonService
 * Method:    apiGetProviderVersion
 * Signature: ()Ljava/lang/String;
 */
JNIEXPORT jstring JNICALL
Java_io_anyone_jni_AnonService_apiGetProviderVersion
(JNIEnv *, jobject);

/*
 * Class:     io_anyone_jni_AnonService
 * Method:    runMain
 * Signature: ()I
 */
JNIEXPORT jint JNICALL
Java_io_anyone_jni_AnonService_runMain
(JNIEnv *, jobject);

/*
 * Class:     io_anyone_jni_AnonService
 * Method:    freeAll
 * Signature: ()V
 */
JNIEXPORT void JNICALL
Java_io_anyone_jni_AnonService_freeAll
(JNIEnv *, jobject);

#endif /* !defined(IO_ANYONE_JNI_ANONSERVICE_H) */
