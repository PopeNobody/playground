#!/bin/bash
if test -n "${API_URL}" && test -n "${API_KEY}" && test -n "${API_MOD}"; then
  echo >&2 "Generic values set"
elif test -n "${AI_PREFIX}"; then
  AI_PREFIX="$(echo -n "$AI_PREFIX" | tr 'a-z' 'A-Z')"
  for i in $(compgen -A variable | grep "^${AI_PREFIX}_"); do
    declare -n src="${i}"
    declare -n dst="${i#${AI_PREFIX}_}"
    dst=$src
  done
else
  echo >&2 "no credentials"
fi
CONTENT="$(cat)"
curl "$API_URL/chat/completions"  \
  -H "Content-Type: application/json"    \
  -H "Authorization: Bearer $API_KEY"   \
  -d "{
  \"messages\" : [
    {
      \"content\" : \"You are a helpful assistant\",
      \"role\" : \"system\"
    },
    {
      \"role\" : \"user\",
      \"content\" : \"${CONTENT}\"
    }
  ],
  \"model\" : \"$API_MOD\"
}" \
  --trace-ascii trace

