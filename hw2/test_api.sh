#!/bin/sh

API_URL="http://192.168.255.69"
STUID="401"
DICT="dictionary.txt"
WORDLEN=5
MAXGUESSES=10
MAXGUESSES_Q=20

# 篩選字典，限制字長
candidates=$(awk -v L=$WORDLEN 'length($0)==L' "$DICT")

# 建立新任務
task=$(curl -s -X POST "$API_URL/tasks" \
  -H "Content-Type: application/json" \
  -d "{\"stuid\":\"$STUID\",\"type\":\"QUORDLE\"}")

echo "Raw response: $task"

task_id=$(echo "$task" | jq -r '.id')
problem1=$(echo "$task" | jq -r '.problem1')
problem2=$(echo "$task" | jq -r '.problem2')
problem3=$(echo "$task" | jq -r '.problem3')
problem4=$(echo "$task" | jq -r '.problem4')

echo "Task ID: $task_id"
echo "Initial problem1: $problem1"
echo "Initial problem2: $problem2"
echo "Initial problem3: $problem3"
echo "Initial problem4: $problem4"

candidates1="$candidates"
candidates2="$candidates"
candidates3="$candidates"
candidates4="$candidates"
solved1=0; solved2=0; solved3=0; solved4=0

for n in $(seq 1 $MAXGUESSES_Q); do
    if [ $solved1 -eq 0 ]; then
       guess=$(printf "%s\n" "$candidates1" | shuf -n 1)
       echo "Guess $n (board1): $guess"
    elif [ $solved2 -eq 0 ]; then
        guess=$(printf "%s\n" "$candidates2" | shuf -n 1)
        echo "Guess $n (board2): $guess"
    elif [ $solved3 -eq 0 ]; then
        guess=$(printf "%s\n" "$candidates3" | shuf -n 1)
        echo "Guess $n (board3): $guess"
    else
        guess=$(printf "%s\n" "$candidates4" | shuf -n 1)
        echo "Guess $n (board4): $guess"
    fi

    resp=$(curl -s -X POST "$API_URL/tasks/$task_id/submit" \
      -H "Content-Type: application/json" \
      -d "{\"answer\":\"$guess\"}")
    echo "Raw response: $resp"
    feedback1=$(echo "$resp" | jq -r '.problem1')
    echo "Feedback1: $feedback1"
    feedback2=$(echo "$resp" | jq -r '.problem2')
    echo "Feedback2: $feedback2"
    feedback3=$(echo "$resp" | jq -r '.problem3')
    echo "Feedback3: $feedback3"
    feedback4=$(echo "$resp" | jq -r '.problem4')
    echo "Feedback4: $feedback4"

    [ "$feedback1" = "AAAAA" ] && solved1=1
    [ "$feedback2" = "AAAAA" ] && solved2=1
    [ "$feedback3" = "AAAAA" ] && solved3=1
    [ "$feedback4" = "AAAAA" ] && solved4=1

   if [ $solved1 -eq 1 ] && [ $solved2 -eq 1 ] && [ $solved3 -eq 1 ] && [ $solved4 -eq 1 ]; then
        echo "Solved all 4 in $n tries!"
        exit 0
   fi

    # 篩選候選字
    candidates1=$(printf "%s\n" $candidates1 | awk -v g="$guess" -v f="$feedback1" '
    {
      word=$0
      ok=1
      for(i=1;i<=length(f);i++){
        gch=substr(g,i,1)
        wch=substr(word,i,1)
        fch=substr(f,i,1)
        if(fch=="A"){
          if(wch!=gch) ok=0
        }
        else if(fch=="B"){
          if(wch==gch || index(word,gch)==0) ok=0
        }
        else if(fch=="X"){
          if(index(word,gch)>0) ok=0
        }
      }
      if(ok) print word
    }')
    candidates2=$(printf "%s\n" $candidates2 | awk -v g="$guess" -v f="$feedback2" '
    {
      word=$0
      ok=1
      for(i=1;i<=length(f);i++){
        gch=substr(g,i,1)
        wch=substr(word,i,1)
        fch=substr(f,i,1)
        if(fch=="A"){
          if(wch!=gch) ok=0
        }
        else if(fch=="B"){
          if(wch==gch || index(word,gch)==0) ok=0
        }
        else if(fch=="X"){
          if(index(word,gch)>0) ok=0
        }
      }
      if(ok) print word
    }')
    candidates3=$(printf "%s\n" $candidates3 | awk -v g="$guess" -v f="$feedback3" '
    {
      word=$0
      ok=1
      for(i=1;i<=length(f);i++){
        gch=substr(g,i,1)
        wch=substr(word,i,1)
        fch=substr(f,i,1)
        if(fch=="A"){
          if(wch!=gch) ok=0
        }
        else if(fch=="B"){
          if(wch==gch || index(word,gch)==0) ok=0
        }
        else if(fch=="X"){
          if(index(word,gch)>0) ok=0
        }
      }
      if(ok) print word
    }')
    candidates4=$(printf "%s\n" $candidates4 | awk -v g="$guess" -v f="$feedback4" '
    {
      word=$0
      ok=1
      for(i=1;i<=length(f);i++){
        gch=substr(g,i,1)
        wch=substr(word,i,1)
        fch=substr(f,i,1)
        if(fch=="A"){
          if(wch!=gch) ok=0
        }
        else if(fch=="B"){
          if(wch==gch || index(word,gch)==0) ok=0
        }
        else if(fch=="X"){
          if(index(word,gch)>0) ok=0
        }
      }
      if(ok) print word
    }')
done

echo "Failed in $MAXGUESSES guesses"
