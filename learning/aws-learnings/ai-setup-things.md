Yes, exactly! Here's the full list of lessons learned from this session:

1. Always save the script to a file and run it with bash Pasting a script block-by-block into CloudShell means each block runs in a separate context — variables like $REGION, $INSTANCE_CONTROLLER etc. don't survive between pastes. Running bash setup.sh keeps everything in one shell process.

2. Disable the AWS pager CloudShell enables an interactive pager by default, which pauses output and waits for keypress. Always add this at the top of any script:

export AWS_PAGER=""

Run in CloudShell
3. Security group names cannot start with sg- AWS reserves the sg-* prefix for security group IDs. Naming a group sg-jenkins-controller throws InvalidParameterValue. Use a suffix instead — e.g. jenkins-controller-sg.

4. Always use explicit --subnet-id with --associate-public-ip-address Using --associate-public-ip-address without specifying --subnet-id can cause run-instances to fail silently when set -e is active.

5. Use ~/ for file paths in CloudShell Writing .pem files without a full path can hit permission issues if the working directory is not writable. Using ~/ ensures files land in the home directory.

6. Download .pem files immediately after creation CloudShell sessions expire and the home directory can be wiped. Download keys right after the script finishes via Actions → Download file.