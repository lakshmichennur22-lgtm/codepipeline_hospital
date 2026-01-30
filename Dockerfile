FROM node:18

# Set working directory inside container
WORKDIR /frontend

# Copy package files from frontend folder
COPY frontend/package*.json ./

# Install dependencies
RUN npm install

# Copy frontend source code
COPY frontend/ .

# Expose application port
EXPOSE 3000

# Start the app
CMD ["npm", "start"]
