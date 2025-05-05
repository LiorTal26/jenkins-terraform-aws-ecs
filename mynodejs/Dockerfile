# Use a small, current Node LTS image
FROM node:22-alpine

WORKDIR /usr/src/app

# Copy dependency manifests first, install prod deps
COPY package*.json ./
RUN npm install --production

# Copy the rest of the source
COPY . .

# Expose the Express port
EXPOSE 3000

# Run the server
CMD ["node", "index.js"]
