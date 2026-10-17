#!/bin/bash
# Field Twin Glaucous v1: lets sign in and sign up links return to field-twin-glaucous.vercel.app as well as chassisquiver.vercel.app.
command -v jq >/dev/null 2>&1 || { apt-get update -y && apt-get install -y jq curl; }
API=https://api.supabase.com/v1
REF=vogxdikogfaxhwcgajfg
TOKEN=${SUPABASE_ACCESS_TOKEN:-$(cat ~/.supabase/access-token 2>/dev/null)}
CUR=$(curl -s "$API/projects/$REF/config/auth" -H "Authorization: Bearer $TOKEN" | jq -r '.uri_allow_list // ""')
NEW="$CUR"
for U in "https://chassisquiver.vercel.app/**" "https://field-twin-glaucous.vercel.app/**"; do
  case ",$NEW," in
    *",$U,"*) ;;
    ",,") NEW="$U" ;;
    *) NEW="$NEW,$U" ;;
  esac
done
NEW=$(echo "$NEW" | sed 's/^,//')
jq -n --arg u "$NEW" '{uri_allow_list:$u, site_url:"https://field-twin-glaucous.vercel.app/"}' > /tmp/field-twin-glaucous-v1-auth.json
curl -s -X PATCH "$API/projects/$REF/config/auth" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" --data-binary @/tmp/field-twin-glaucous-v1-auth.json | jq -r '"REDIRECT LIST: " + (.uri_allow_list // "not set")'
