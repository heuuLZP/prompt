cat statusline.sh
#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract values using jq
model_display=$(echo "$input" | jq -r '.model.display_name')
model_id=$(echo "$input" | jq -r '.model.id')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir' | xargs basename)
transcript_path=$(echo "$input" | jq -r '.transcript_path')

# Format model display name to show "Sonnet 4[1m]" for 1M context models
if [[ "$model_id" == *"[1m]"* ]] || [[ "$model_display" == *"1M token context"* ]] || [[ "$model_display" == *"1m"* ]]; then
    model_display="Sonnet 4[1m]"
else
    model_display="Sonnet 4"
fi

# Determine context limit based on model
context_limit=200000  # Default 200K
# Check model id for [1m] suffix or display name for 1M context indicators
if [[ "$model_id" == *"[1m]"* ]] || [[ "$model_display" == *"1M token context"* ]] || [[ "$model_display" == *"1m"* ]]; then
    context_limit=1000000  # 1M for models with 1M context
fi

# Calculate context usage from transcript
context_percentage=""
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
    # Get the most recent main chain entry's usage
    recent_entry=$(tail -n 20 "$transcript_path" | grep -v '"isSidechain":true' | tail -n 1)

    if [ -n "$recent_entry" ]; then
        # Extract token usage
        input_tokens=$(echo "$recent_entry" | jq -r '.message.usage.input_tokens // 0')
        cache_creation=$(echo "$recent_entry" | jq -r '.message.usage.cache_creation_input_tokens // 0')
        cache_read=$(echo "$recent_entry" | jq -r '.message.usage.cache_read_input_tokens // 0')

        # Calculate total context length
        context_length=$((input_tokens + cache_creation + cache_read))

        # Calculate percentage (dynamic token limit based on model)
        if [ "$context_length" -gt 0 ]; then
            percentage=$((100 - context_length * 100 / context_limit))
            if [ "$percentage" -lt 0 ]; then
                percentage=0
            fi
            context_percentage="$percentage% context left"
        fi
    fi
fi

# Build status line with custom color scheme and a|b (c) format
# Colors: Directory=#3B82F6=ANSI 33, Model=#8B5CF6=ANSI 141, Context=#97a0b0=ANSI 247
if [ -n "$context_percentage" ]; then
    printf "\033[38;5;33m%s\033[0m | \033[38;5;141m%s\033[0m (\033[38;5;247m%s\033[0m)\n" "$current_dir" "$model_display" "$context_percentage"
else
    printf "\033[38;5;33m%s\033[0m | \033[38;5;141m%s\033[0m\n" "$current_dir" "$model_display"
fi%                     
