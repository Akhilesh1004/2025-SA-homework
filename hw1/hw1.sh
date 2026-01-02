#!/bin/sh


print_help() {
    printf "hw1.sh -t TASK_TYPE [-h]\n\n" >&2
    echo "Available Options:" >&2
    echo "-t SYS_INFO | WORDLE | QUORDLE : Task type" >&2
    echo "-h : Show the script usage" >&2
}

TASK_TYPE=""
SHOW_HELP=0
API_URL="http://192.168.255.69"
STUID="401"
DICT="dictionary.txt"
WORDLEN=5
MAXGUESSES=10
MAXGUESSES_Q=20

candidates=$(awk -v L=$WORDLEN 'length($0)==L' "$DICT")

clean_timeout(){
    # list all tasks for this student
    tasks=$(curl -s "$API_URL/tasks/stu/$STUID" | jq -r '.tasks[].id')

    for id in $tasks; do
        status=$(curl -s "$API_URL/tasks/$id" | jq -r '.status')

        echo "Task $id -> status=$status"

        if [ "$status" = "TIMEOUT" ] || [ "$status" = "SOLVED" ]; then
            echo "Deleting $id ..."
            curl -s -X DELETE "$API_URL/tasks/$id" >/dev/null
        fi
    done
}

filter_candidates() {
    candidates="$1"
    guess="$2"
    feedback="$3"

    printf "%s\n" $candidates | awk -v g="$guess" -v f="$feedback" '
    {
      word=$0
      ok=1
      for(i=1;i<=length(f);i++){
        gch=substr(g,i,1)   # guess 的字母
        wch=substr(word,i,1) # 候選字的字母
        fch=substr(f,i,1)   # feedback 的標記 (A/B/X)
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
    }'
}


while getopts ":t:h" opt; do
    case "$opt" in
        t)
            case "$OPTARG" in
                SYS_INFO|WORDLE|QUORDLE)
                    TASK_TYPE="$OPTARG"
                    ;;
                *)
                    print_help
                    exit 1
                    ;;
            esac
            ;;
        h)
            SHOW_HELP=1
            ;;
        :)
            # Missing argument for option
            print_help
            exit 1
            ;;
        \?)
            # Invalid option
            print_help
            exit 1
            ;;
    esac
done

# If -h is specified, print usage and exit 0
if [ "$SHOW_HELP" -eq 1 ]; then
    print_help
    exit 0
fi

# If no task type is provided, reject
if [ -z "$TASK_TYPE" ]; then
    print_help
    exit 1
fi

# ---- Main logic dispatch ----
case "$TASK_TYPE" in
    SYS_INFO)
        echo "OS: $(grep PRETTY_NAME /etc/os-release | cut -d= -f2- | tr -d \")"
        echo "Kernel: $(uname -r)"
        echo "Shell: $(basename "$SHELL")"
        echo "Terminal: $(tty)"
        echo "CPU: $(lscpu | grep 'Model name:' | sed 's/Model name:[ ]*//')"
        ;;
    WORDLE)
        # create new tasks
	task=$(curl -s -X POST "$API_URL/tasks" \
	  -H "Content-Type: application/json" \
	  -d "{\"stuid\":\"$STUID\",\"type\":\"WORDLE\"}")

	echo "Raw response: $task"

	task_id=$(echo "$task" | jq -r '.id')
	problem=$(echo "$task" | jq -r '.problem')
	
	clean_timeout
	
	echo "Task ID: $task_id"
	echo "Initial problem: $problem"
        for n in $(seq 1 $MAXGUESSES); do
	    guess=$(printf "%s\n" "$candidates" | shuf -n 1)
	    echo "Guess $n: $guess"

	    resp=$(curl -s -X POST "$API_URL/tasks/$task_id/submit" \
	      -H "Content-Type: application/json" \
	      -d "{\"answer\":\"$guess\"}")
	    echo "Raw response: $resp"
	    feedback=$(echo "$resp" | jq -r '.problem')
	    echo "Feedback: $feedback"

	    [ "$feedback" = "AAAAA" ] && {
	        echo "Solved in $n tries: $guess"
	        exit 0
	    }

	    # fliter the candidate
	    candidates=$(filter_candidates "$candidates" "$guess" "$feedback")
	done

	echo "Failed in $MAXGUESSES guesses"
	;;
    QUORDLE)
	# create new task
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
        
	clean_timeout

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
	   candidates1=$(filter_candidates "$candidates1" "$guess" "$feedback1")
	   candidates2=$(filter_candidates "$candidates2" "$guess" "$feedback2")
	   candidates3=$(filter_candidates "$candidates3" "$guess" "$feedback3")
	   candidates4=$(filter_candidates "$candidates4" "$guess" "$feedback4")
	done

	echo "Failed in $MAXGUESSES_Q guesses"
        ;;
esac
