#!/bin/bash


curl https://api.x.ai/v1/models  \
  -H "Content-Type: application/json"    \
  -H "Authorization: Bearer $API_KEY"   \
  --trace-ascii trace
