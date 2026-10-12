#!/bin/bash
cd ~/chassisquiver || exit 1
command -v jq >/dev/null 2>&1 || { apt-get update -y && apt-get install -y jq curl; }
API=https://api.supabase.com/v1
TOKEN=${SUPABASE_ACCESS_TOKEN:-$(cat ~/.supabase/access-token 2>/dev/null)}
ORG=$(supabase orgs list -o json | jq -r '(map(select(.name=="Mohave Tech"))[0] // .[0]).id')
REF=$(supabase projects list -o json | jq -r '.[] | select(.name=="chassisquiver") | .id' | head -n 1)
if [ -z "$REF" ]; then
  DBPW=$(head -c 32 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 24)
  echo "SAVE THIS DATABASE PASSWORD: $DBPW"
  REF=$(supabase projects create chassisquiver --org-id "$ORG" --db-password "$DBPW" --region us-west-1 -o json | jq -r '.id // empty')
fi
if [ -z "$REF" ]; then echo "PROJECT WAS NOT CREATED"; exit 1; fi
echo "SAVE THIS PROJECT REF: $REF"
echo "Waiting for the database to come online"
for i in $(seq 1 90); do
  ST=$(curl -s "$API/projects/$REF" -H "Authorization: Bearer $TOKEN" | jq -r '.status // empty')
  [ "$ST" = "ACTIVE_HEALTHY" ] && break
  sleep 10
done
jq -Rs '{query: .}' supabase/chassisquiver-v1-setup.sql > /tmp/chassisquiver-v1-query.json
for i in $(seq 1 12); do
  OUT=$(curl -s -X POST "$API/projects/$REF/database/query" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" --data-binary @/tmp/chassisquiver-v1-query.json)
  echo "$OUT" | grep -q '"message"' || break
  sleep 10
done
echo "TABLE SETUP: $OUT"
jq -n '{site_url:"https://chassisquiver.vercel.app", uri_allow_list:"https://chassisquiver.vercel.app/**", mailer_autoconfirm:true}' > /tmp/chassisquiver-v1-auth.json
curl -s -X PATCH "$API/projects/$REF/config/auth" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" --data-binary @/tmp/chassisquiver-v1-auth.json | jq -r '"AUTH SITE: " + (.site_url // "not set")'
KEY=$(curl -s "$API/projects/$REF/api-keys" -H "Authorization: Bearer $TOKEN" | jq -r '.[] | select(.name=="anon") | .api_key')
echo "SAVE THIS ANON KEY: $KEY"
