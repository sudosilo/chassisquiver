#!/bin/bash
cd ~/chassisquiver || exit 1
command -v jq >/dev/null 2>&1 || { apt-get update -y && apt-get install -y jq curl; }
API=https://api.supabase.com/v1
REF=vogxdikogfaxhwcgajfg
TOKEN=${SUPABASE_ACCESS_TOKEN:-$(cat ~/.supabase/access-token 2>/dev/null)}
for F in $(ls supabase/chassisquiver-v*.sql | sort); do
  jq -Rs '{query: .}' "$F" > /tmp/chassisquiver-v1-query.json
  OUT=$(curl -s -X POST "$API/projects/$REF/database/query" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" --data-binary @/tmp/chassisquiver-v1-query.json)
  echo "DATABASE $F: $OUT"
done
CUR=$(curl -s "$API/projects/$REF/config/auth" -H "Authorization: Bearer $TOKEN" | jq -r '.uri_allow_list // ""')
case "$CUR" in
  *chassisquiver.vercel.app*) NEW="$CUR" ;;
  "") NEW="https://chassisquiver.vercel.app/**" ;;
  *) NEW="$CUR,https://chassisquiver.vercel.app/**" ;;
esac
jq -n --arg u "$NEW" '{uri_allow_list:$u, mailer_autoconfirm:true}' > /tmp/chassisquiver-v1-auth.json
curl -s -X PATCH "$API/projects/$REF/config/auth" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" --data-binary @/tmp/chassisquiver-v1-auth.json | jq -r '"REDIRECT LIST: " + (.uri_allow_list // "not set")'
KEY=$(curl -s "$API/projects/$REF/api-keys" -H "Authorization: Bearer $TOKEN" | jq -r '.[] | select(.name=="anon") | .api_key')
echo "SAVE THIS ANON KEY: $KEY"
