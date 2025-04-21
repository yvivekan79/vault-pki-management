#!/bin/bash

# Initialize Git repository
git init

# Add all files except those in .gitignore
git add .

# Create the initial commit
git commit -m "Initial commit: Vault PKI Infrastructure with SoftHSM Integration"

# Instructions for adding a remote repository
echo "Git repository initialized with initial commit."
echo ""
echo "Next steps:"
echo "1. Create a repository on GitHub, GitLab, or your preferred Git hosting service"
echo "2. Add the remote repository:"
echo "   git remote add origin <repository-url>"
echo "3. Push the code to the remote repository:"
echo "   git push -u origin master"
echo ""
echo "Done!"