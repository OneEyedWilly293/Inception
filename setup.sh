# setup.sh
#!/bin/sh
mkdir -p secrets

printf "Enter db_name: ";        read v; echo "$v" > secrets/db_name.txt
printf "Enter db_user: ";        read v; echo "$v" > secrets/db_user.txt
printf "Enter db_password: ";    read v; echo "$v" > secrets/db_password.txt
printf "Enter db_root_password: "; read v; echo "$v" > secrets/db_root_password.txt
printf "Enter wp_admin: ";       read v; echo "$v" > secrets/wp_admin.txt
printf "Enter wp_admin_password: "; read v; echo "$v" > secrets/wp_admin_password.txt
printf "Enter wp_admin_email: "; read v; echo "$v" > secrets/wp_admin_email.txt
printf "Enter wp_user: ";        read v; echo "$v" > secrets/wp_user.txt
printf "Enter wp_user_password: "; read v; echo "$v" > secrets/wp_user_password.txt
printf "Enter wp_user_email: ";  read v; echo "$v" > secrets/wp_user_email.txt

echo "Secrets created successfully."
