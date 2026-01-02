#!/bin/sh

DICT="dictionary.txt"
WORDLEN=5
MAXGUESSES=10

candidates=$(awk -v L=$WORDLEN 'length($0)==L' "$DICT")

for n in $(seq 1 $MAXGUESSES); do
    guess=$(printf "%s\n" "$candidates" | shuf -n 1)
    echo "Guess $n: $guess"
    echo "Feedback? (G=green Y=yellow .=gray)"
    read feedback

    [ "$feedback" = "GGGGG" ] && {
        echo "Solved in $n tries: $guess"
        exit 0
    }

    candidates=$(printf "%s\n" $candidates | awk -v g="$guess" -v f="$feedback" '
{
  word=$0
  ok=1
  for(i=1;i<=length(f);i++){
    gch=substr(g,i,1)   # guess 的字母
    wch=substr(word,i,1) # 候選字的字母
    fch=substr(f,i,1)   # feedback 的標記 (G/Y/.)
    if(fch=="G"){ 
      if(wch!=gch) ok=0
    }
    else if(fch=="Y"){ 
      if(wch==gch || index(word,gch)==0) ok=0
    }
    else if(fch=="."){ 
      if(index(word,gch)>0) ok=0
    }
  }
  if(ok) print word
}')
done

echo "Failed in $MAXGUESSES guesses"

