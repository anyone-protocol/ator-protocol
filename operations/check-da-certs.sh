ips="

"
for ip in $ips; do
  echo "== $ip =="
  curl -s http://$ip:9230/tor/keys/authority | grep -E 'dir-key-(published|expires)'
done
