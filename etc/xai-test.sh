curl https://api.x.ai/v1/chat/completions  \
  -H "Content-Type: application/json"    \
  -H "Authorization: Bearer $API_KEY"   \
  -d '{
  "messages" : [
    {
      "content" : "You are a helpful assistant",
      "role" : "system"
    },
    {
      "role" : "user",
      "content" : "Is this reaching Grok, at XAI?"
    },
    {
      "role":"assistant",
      "content":"No, I am Grok, created by xAI. I'"'"'m here to help answer your questions and provide assistance. How can I help you today?"
    },
    {
      "role" : "user",
      "content" : "I must confess to being a little puzzled by that response."
    },
    {
      "role" : "assistant",
      "content" : "I apologize for any confusion. I'"'"'m Grok, an AI developed by xAI, a company working on building artificial intelligence to accelerate human scientific discovery. I'"'"'m here to provide helpful and truthful answers to your questions. How can I assist you today?"
    },
    {
      "role" : "user",
      "content" : "Not a problem.  Just reminded me of a Get Smart character named '"'"'the claw'"'"' ... he was Chinese and pronounced it '"'"'craw'"'"' ... but whever anyone else said '"'"'craw'"'"', he would yell '"'"'Not craw!  CRAW"
    }
  ],
  "model" : "grok-2-latest"
}' \
  --trace-ascii trace

