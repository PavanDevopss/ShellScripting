#!/bin/bash

# Make sure to run this script as root or with sudo privileges.

# 1. Update System Packages
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# 2. Install Essential Packages (Git, curl, vim, etc.)
echo "Installing essential packages..."
sudo apt install -y git curl vim ufw

# 3. Install Node.js and npm
echo "Installing Node.js and npm..."
curl -sL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# 4. Install PostgreSQL
echo "Installing PostgreSQL..."
sudo apt install -y postgresql postgresql-contrib

# 5. Install PM2 (for running Node.js in the background)
echo "Installing PM2..."
sudo npm install -g pm2

# 6. Install Nginx (to serve ReactJS and reverse proxy Node.js)
echo "Installing Nginx..."
sudo apt install -y nginx

# 7. Set Up SSH Keys for Bitbucket (if not already set)
echo "Setting up SSH keys for Bitbucket..."
if [ ! -f "$HOME/.ssh/id_rsa" ]; then
    echo "Generating SSH key..."
    ssh-keygen -t rsa -b 4096 -C "your-email@example.com" -f "$HOME/.ssh/id_rsa" -N ""
fi

echo "Displaying the SSH public key for Bitbucket setup:"
cat "$HOME/.ssh/id_rsa.pub"
echo "Copy the above SSH key to your Bitbucket account (under Personal Settings > SSH Keys)."

# 8. Clone the Bitbucket repository
echo "Cloning the Bitbucket repository..."
git clone git@bitbucket.org:yourusername/yourrepository.git /var/www/yourapp
cd /var/www/yourapp

# 9. Install Backend Dependencies (Node.js)
echo "Installing backend dependencies..."
cd backend  # Assuming your Node.js app is in a 'backend' directory
npm install

# 10. Set Up PostgreSQL Database
echo "Setting up PostgreSQL database..."
sudo -u postgres psql -c "CREATE DATABASE yourdatabase;"
sudo -u postgres psql -c "CREATE USER yourusername WITH ENCRYPTED PASSWORD 'yourpassword';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE yourdatabase TO yourusername;"

# 11. Set Up .env File (if required for your Node.js app)
echo "Creating .env file for Node.js app..."
cat <<EOL > /var/www/yourapp/backend/.env
DATABASE_URL=postgres://yourusername:yourpassword@localhost:5432/yourdatabase
PORT=5000
EOL

# 12. Install Frontend Dependencies (React)
echo "Installing frontend dependencies..."
cd /var/www/yourapp/frontend  # Assuming your React app is in a 'frontend' directory
npm install

# 13. Build the React App for Production
echo "Building the React app for production..."
npm run build

# 14. Configure Nginx to Serve React and Reverse Proxy Node.js
echo "Configuring Nginx..."
sudo bash -c 'cat > /etc/nginx/sites-available/yourapp <<EOF
server {
    listen 80;
    server_name yourdomain.com;

    # Serve React frontend
    location / {
        root /var/www/yourapp/frontend/build;
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

# Enable the site and restart Nginx
sudo ln -s /etc/nginx/sites-available/yourapp /etc/nginx/sites-enabled/
sudo systemctl restart nginx

# 15. Start Node.js Backend with PM2
echo "Starting Node.js backend with PM2..."
cd /var/www/yourapp/backend
pm2 start server.js  # Replace with the actual entry point of your app (e.g., app.js)
pm2 save  # Save PM2 process list for automatic restart on reboot

# 16. Set Up PM2 to Restart on Reboot
echo "Setting up PM2 to restart on reboot..."
pm2 startup systemd
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u $USER --hp $HOME

# 17. Check that everything is running
echo "Checking the status of services..."
pm2 status
sudo systemctl status nginx
sudo systemctl status postgresql

# 18. Test the Application
echo "Test the application by navigating to your server IP or domain (http://yourdomain.com)."

# 19. Secure the Server (Optional: Firewall and SSH Security)
echo "Configuring firewall to allow HTTP, HTTPS, and SSH traffic..."
sudo ufw allow 22/tcp   # Allow SSH
sudo ufw allow 80/tcp   # Allow HTTP
sudo ufw allow 443/tcp  # Allow HTTPS
sudo ufw enable

# OPTIONAL: Disable root SSH login (Commented out to avoid disconnection)
# echo "Disabling root SSH login (for security)..."
# sudo sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
# sudo systemctl restart sshd

echo "All done! Your application should now be up and running."

# End of Script
