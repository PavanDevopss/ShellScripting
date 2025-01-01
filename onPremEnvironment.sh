#!/bin/bash

# Make sure to run this script as root or with sudo privileges.

# Function to check for the success of the last command and exit if it failed
check_command() {
    if [ $? -ne 0 ]; then
        echo "Error occurred during the previous step. Exiting."
        exit 1
    fi
}

# 1. Update System Packages
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y
check_command

# 2. Install Essential Packages (Git, curl, vim, ufw)
echo "Installing essential packages..."

# Check if packages are already installed and update if needed
for package in git curl vim ufw; do
    if dpkg -l | grep -qw $package; then
        echo "$package is already installed. Updating..."
        sudo apt install --only-upgrade $package -y
    else
        echo "$package is not installed. Installing..."
        sudo apt install -y $package
    fi
done
check_command

# 2.1 Install PostgreSQL
echo "Installing PostgreSQL..."
sudo apt install -y postgresql postgresql-contrib

# 3. Install Node.js and npm
echo "Installing Node.js and npm..."
if ! command -v node &> /dev/null; then
    curl -sL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt install -y nodejs
    check_command
else
    echo "Node.js is already installed. Updating..."
    sudo apt install --only-upgrade nodejs -y
    check_command
fi

# 4. Install PM2 (for running Node.js in the background)
echo "Installing PM2..."
if ! command -v pm2 &> /dev/null; then
    sudo npm install -g pm2
    check_command
else
    echo "PM2 is already installed. Updating..."
    sudo npm update -g pm2
    check_command
fi

# 5. Install Nginx (to serve ReactJS and reverse proxy Node.js)
echo "Installing Nginx..."
if ! dpkg -l | grep -qw nginx; then
    sudo apt install -y nginx
    check_command
else
    echo "Nginx is already installed. Updating..."
    sudo apt install --only-upgrade nginx -y
    check_command
fi

# 6. Set Up SSH Keys for Bitbucket (if not already set)
echo "Setting up SSH keys for Bitbucket..."
if [ ! -f "$HOME/.ssh/id_rsa" ]; then
    echo "Generating SSH key..."
    ssh-keygen -t rsa -b 4096 -C "iampavan.blue.com" -f "$HOME/.ssh/id_rsa" -N ""
    check_command
else
    echo "SSH key already exists."
fi

echo "Displaying the SSH public key for Bitbucket setup:"
cat "$HOME/.ssh/id_rsa.pub"
echo "Copy the above SSH key to your Bitbucket account (under Personal Settings > SSH Keys)."

# 7. Clone the Bitbucket repository
echo "Cloning the Bitbucket repository..."
if [ ! -d "/var/www/pernapp" ]; then
    git clone git@github.com:PavanDevopss/pernapp.git /var/www/pernapp
    check_command
else
    echo "Repository already cloned in /var/www/pernapp. Skipping clone."
fi
cd /var/www/pernapp

# 8. Install Backend Dependencies (Node.js)
echo "Installing backend dependencies..."
if [ -d "backend" ]; then
    cd backend  # Assuming your Node.js app is in a 'backend' directory
    npm install
    check_command
else
    echo "'backend' directory not found. Skipping backend dependencies installation."
fi

# 9. Set Up .env File (Use AWS PostgreSQL Database)
log_output "Creating .env file for Node.js app..."
cat <<EOL > /var/www/pernapp/backend/.env
# Environment variables for Node.js and PostgreSQL
PORT=5000
PG_USER=pavan
PG_HOST=localhost
PG_DB=sampledb
PG_PASSWORD=password
PG_PORT=5432
EOL
check_command

# 9.1 Set Up PostgreSQL Database
echo "Setting up PostgreSQL database..."
sudo -u postgres psql -d sampledb -c "CREATE TABLE items (id SERIAL PRIMARY KEY, name VARCHAR(100) NOT NULL);"
sudo -u postgres psql -c "CREATE USER pavan WITH ENCRYPTED PASSWORD '00998877';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE sampledb TO pavan;"

# 10. Install Frontend Dependencies (React)
echo "Installing frontend dependencies..."
if [ -d "frontend" ]; then
    cd /var/www/pernapp/frontend  # Assuming your React app is in a 'frontend' directory
    npm install
    check_command
else
    echo "'frontend' directory not found. Skipping frontend dependencies installation."
fi

# 11. Build the React App for Production
echo "Building the React app for production..."
if [ -d "frontend" ]; then
    cd /var/www/pernapp/frontend
    npm run build
    check_command
else
    echo "'frontend' directory not found. Skipping React build."
fi

# 12. Configure Nginx to Serve React and Reverse Proxy Node.js
echo "Configuring Nginx..."
sudo bash -c 'cat > /etc/nginx/sites-available/pernapp <<EOF
server {
    listen 80;
    server_name yourdomain.com;

    # Serve React frontend
    location / {
        root /var/www/pernapp/frontend/build;
        try_files \$uri /index.html;
    }

    # Proxy requests to Node.js backend
    location /api/ {
        proxy_pass http://localhost:5000/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF'
check_command

# Enable the site and restart Nginx
sudo ln -s /etc/nginx/sites-available/pernapp /etc/nginx/sites-enabled/
sudo systemctl restart nginx
check_command

# 13. Start Node.js Backend with PM2
echo "Starting Node.js backend with PM2..."
if [ -f "/var/www/pernapp/backend/server.js" ]; then
    cd /var/www/pernapp/backend
    pm2 start server.js  # Replace with the actual entry point of your app (e.g., app.js)
    pm2 save  # Save PM2 process list for automatic restart on reboot
    check_command
else
    echo "Backend entry point 'server.js' not found. Skipping PM2 start."
fi

# 14. Set Up PM2 to Restart on Reboot
echo "Setting up PM2 to restart on reboot..."
pm2 startup systemd
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u $USER --hp $HOME
check_command

# 15. Check that everything is running
echo "Checking the status of services..."
pm2 status
check_command
sudo systemctl status nginx
check_command

# 16. Test the Application
echo "Test the application by navigating to your server IP or domain (http://yourdomain.com)."

# 17. Secure the Server (Optional: Firewall and SSH Security)
echo "Configuring firewall to allow HTTP, HTTPS, and SSH traffic..."
sudo ufw allow ssh          # Allow SSH (port 22)
sudo ufw allow 22/tcp       # Allow SSH
sudo ufw allow 80/tcp       # Allow HTTP (port 80)
sudo ufw allow 443/tcp      # Allow HTTPS (port 443)
sudo ufw allow 5000/tcp     # If you need to allow port 5000 (custom web app)
sudo ufw allow 5432/tcp     # If you need to allow PostgreSQL
sudo ufw enable
check_command

# 18. Ensure SSH is enabled and properly configured
echo "Ensuring SSH is enabled and properly configured..."
sudo systemctl enable ssh
sudo systemctl start ssh
check_command

# OPTIONAL: Disable root SSH login (Commented out to avoid disconnection)
# echo "Disabling root SSH login (for security)..."
# sudo sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
# sudo systemctl restart sshd

echo "All done! Your application should now be up and running."

# End of Script
