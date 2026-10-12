#!/data/data/com.termux/files/usr/bin/bash
cd ~/chassisquiver || exit 1
KEY=$(proot-distro login ubuntu -- bash -lc 'TOKEN=${SUPABASE_ACCESS_TOKEN:-$(cat ~/.supabase/access-token 2>/dev/null)}; curl -s "https://api.supabase.com/v1/projects/vogxdikogfaxhwcgajfg/api-keys" -H "Authorization: Bearer $TOKEN" | jq -r ".[] | select(.name==\"anon\") | .api_key"' | grep -o 'eyJ[A-Za-z0-9._-]*' | head -n 1)
if [ -z "$KEY" ]; then echo "ANON KEY NOT FOUND"; exit 1; fi
printf "window.CHASSISQUIVER_CONFIG={url:'https://vogxdikogfaxhwcgajfg.supabase.co',key:'%s'};\n" "$KEY" > chassisquiver-v1-config.js
echo "WROTE chassisquiver-v1-config.js"
gh auth setup-git
git add chassisquiver-v1-config.js
git -c user.name=sudosilo -c user.email=sudosilo@users.noreply.github.com commit -m "Chassisquiver v1: Supabase anon key config"
git push origin main
