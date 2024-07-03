#!/bin/bash

# Check if the input file is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <input_file>"
  exit 1
fi

INPUT_FILE="$1"
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.csv"

# Ensure the log file exists
touch "$LOG_FILE"

# Ensure the secure directory and password file exist with correct permissions
mkdir -p /var/secure
touch "$PASSWORD_FILE"
chmod 600 "$PASSWORD_FILE"

# Function to generate a random password
generate_password() {
  tr -dc A-Za-z0-9 </dev/urandom | head -c 12 ; echo ''
}

# Read the input file line by line
while IFS=";" read -r user groups; do
  # Remove leading/trailing whitespace from user and groups
  user=$(echo "$user" | xargs)
  groups=$(echo "$groups" | xargs)

  # Create a personal group with the same name as the user
  if ! getent group "$user" &>/dev/null; then
    groupadd "$user"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - Created personal group $user" | tee -a "$LOG_FILE"
  fi

  if id "$user" &>/dev/null; then
    echo "$(date +'%Y-%m-%d %H:%M:%S') - User $user already exists. Skipping..." | tee -a "$LOG_FILE"
    continue
  fi

  # Create the user with the personal group
  useradd -m -s /bin/bash -g "$user" "$user"
  echo "$(date +'%Y-%m-%d %H:%M:%S') - Created user $user with personal group $user" | tee -a "$LOG_FILE"

  # Set the home directory permissions
  chmod 700 "/home/$user"
  chown "$user:$user" "/home/$user"
  echo "$(date +'%Y-%m-%d %H:%M:%S') - Set permissions for /home/$user" | tee -a "$LOG_FILE"

  # Generate a random password and set it
  password=$(generate_password)
  echo "$user:$password" | chpasswd
  echo "$(date +'%Y-%m-%d %H:%M:%S') - Set password for $user" | tee -a "$LOG_FILE"

  # Securely store the password
  echo "$user,$password" >> "$PASSWORD_FILE"
  echo "$(date +'%Y-%m-%d %H:%M:%S') - Stored password for $user in $PASSWORD_FILE" | tee -a "$LOG_FILE"

  # Add user to specified groups
  IFS="," read -r -a group_array <<< "$groups"
  for group in "${group_array[@]}"; do
    group=$(echo "$group" | xargs)  # Remove leading/trailing whitespace
    if ! getent group "$group" &>/dev/null; then
      groupadd "$group"
      echo "$(date +'%Y-%m-%d %H:%M:%S') - Created group $group" | tee -a "$LOG_FILE"
    fi
    usermod -aG "$group" "$user"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - Added user $user to group $group" | tee -a "$LOG_FILE"
  done

done < "$INPUT_FILE"

echo "$(date +'%Y-%m-%d %H:%M:%S') - User creation process completed." | tee -a "$LOG_FILE"
