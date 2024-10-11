// Initialize the socket connection
const socket = io(`wss://${window.location.hostname}`, {  // hostname is ALB DNS
    path: "/socket.io",
    transports: ["websocket"],
    query: { username: username },
});

// Get references to the DOM elements
const messageInput = document.getElementById("message-input");
const chatMessages = document.getElementById("chat-messages");
const sendBtn = document.getElementById("send-btn");
const leaveRoomBtn = document.getElementById("leave-room-btn");

// Get other user's name from session storage
const other_user = sessionStorage.getItem("other_user");
document.getElementById("chat-other-user").textContent = other_user;


// RSA encryption for encrypting the AES key
let privateKey, publicKey;
let otherUserPublicKey;

async function generateKeyPair() {
    console.log("[INFO] Generating RSA key pair...");
    const keyPair = await window.crypto.subtle.generateKey(
        {
            name: "RSA-OAEP",
            modulusLength: 2048,
            publicExponent: new Uint8Array([1, 0, 1]),
            hash: { name: "SHA-256" },
        },
        true, // Extractable (can export the public key)
        ["encrypt", "decrypt"]
    );
    return keyPair;
}

async function encryptAESKey(aesKey, otherUserPublicKey) {
    console.log("[INFO] Encrypting AES key with recipient's public RSA key...");
    const ciphertext = await window.crypto.subtle.encrypt(
        {
            name: "RSA-OAEP"
        },
        otherUserPublicKey,
        aesKey
    );
    return ciphertext;
}

async function decryptAESKey(encryptedAESKey, privateKey) {
    console.log("[INFO] Decrypting AES key with private RSA key...");
    return await window.crypto.subtle.decrypt(
        {
            name: "RSA-OAEP"
        },
        privateKey,
        encryptedAESKey
    );
}


// AES encryption for the actual message
async function generateAESKey() {
    console.log("[INFO] Generating AES key...");
    return window.crypto.subtle.generateKey(
        {
            name: "AES-GCM",
            length: 256,
        },
        true, // Extractable (can export the public key)
        ["encrypt", "decrypt"]
    );
}

async function encryptWithAES(message, aesKey) {
    console.log("[INFO] Encrypting message with AES...");
    const encoder = new TextEncoder();
    const iv = window.crypto.getRandomValues(new Uint8Array(12));
    const encodedMessage = encoder.encode(message);

    const ciphertext = await window.crypto.subtle.encrypt(
        {
            name: "AES-GCM",
            iv: iv,
        },
        aesKey,
        encodedMessage
    );

    return { iv, ciphertext };
}

async function decryptWithAES(ciphertext, iv, aesKey) {
    console.log("[INFO] Decrypting message with AES...");
    const decrypted = await window.crypto.subtle.decrypt(
        {
            name: "AES-GCM",
            iv: iv,
        },
        aesKey,
        ciphertext
    );

    const decoder = new TextDecoder();
    return decoder.decode(decrypted);
}


// Functions for importing and exporting keys for sharing
async function exportPublicKey(key) {
    console.log("[INFO] Exporting public RSA key...");
    return window.crypto.subtle.exportKey("spki", key);
}

async function importPublicKey(keyData) {
    console.log("[INFO] Importing public RSA key...");
    return window.crypto.subtle.importKey(
        "spki",
        keyData,
        { name: "RSA-OAEP", hash: { name: "SHA-256" } },
        true, // Can be used for encrypting messages
        ["encrypt"]
    );
}

async function exportAESKey(key) {
    console.log("[INFO] Exporting AES key...");
    return window.crypto.subtle.exportKey("raw", key);
}

async function importAESKey(keyData) {
    console.log("[INFO] Importing AES key...");
    return window.crypto.subtle.importKey(
        "raw",
        keyData,
        { name: "AES-GCM" },
        false,
        ["decrypt"]
    );
}


// Send an encrypted message to the server
async function sendMessage() {
    const message = messageInput.value.trim();
    
    // Check if message is empty
    if (!message) {
        console.error("[ERROR] No message to send");
        return;
    }

    // Check if the recipient's public key is available
    if (!otherUserPublicKey) {
        console.error("[ERROR] No public key for the recipient");
        return;
    }

    console.log("[INFO] Sending message...");

    // Step 1: Generate a symmetric AES key for encrypting the message
    const aesKey = await generateAESKey();

    // Step 2: Encrypt the message with AES
    const { iv, ciphertext } = await encryptWithAES(message, aesKey);

    // Step 3: Encrypt the AES key with the recipient's public RSA key
    const exportedAESKey = await exportAESKey(aesKey);
    const encryptedAESKey = await encryptAESKey(exportedAESKey, otherUserPublicKey);

    // Step 4: Send both the encrypted AES key and the encrypted message (ciphertext)
    socket.emit("send_message", {
        room_id: room_id,
        aes_key: Array.from(new Uint8Array(encryptedAESKey)),
        iv: Array.from(iv), // Send IV along with ciphertext
        message: Array.from(new Uint8Array(ciphertext)),
        username: username
    });

    messageInput.value = "";  // Clear input field after sending

    console.log("[INFO] Message sent");

    // Step 5: Append the message to your own chat window (plaintext)
    const messageElement = document.createElement("div");
    messageElement.classList.add("message");
    messageElement.innerHTML = `<strong>${username}:</strong> ${message}`;
    chatMessages.appendChild(messageElement);
    scrollToBottom(); // Scroll the chat to the bottom
};

// Scroll chat to the latest message
function scrollToBottom() {
    chatMessages.scrollTop = chatMessages.scrollHeight;
}


// Event handlers

// Handle sending a message when the "Send" button is clicked
sendBtn.addEventListener("click", sendMessage);

// Handle sending a message when pressing "Enter" in the input field
messageInput.addEventListener("keypress", (e) => {
    if (e.key === "Enter") {
        sendMessage();
    }
});

// Handle "Back to Lobby" button click
leaveRoomBtn.addEventListener("click", () => {
    console.log(`[INFO] User '${username}' leaving the room`);
    socket.emit("leave_room", { username: username, room_id: room_id });
    window.location.href = "/lobby";
});


// Socket event listeners

// When connected, join the room
socket.on("connect", () => {
    console.log("[INFO] Connected to the chat room");
    socket.emit("join_room", { username: username, room_id: room_id });
});

// Handle room join failure and redirect
socket.on("join_room_failure", () => {
    console.warn("[WARNING] Room join failed. Redirecting to unauthorized page.");
    window.location.href = "/unauthorized";
});

// Generate keys and share public key upon joining the room
socket.on("join_room_success", async () => {
    console.log("[INFO] Successfully joined chat room");

    // Generate the RSA key pair for this user
    const keyPair = await generateKeyPair();
    privateKey = keyPair.privateKey;
    publicKey = keyPair.publicKey;

    // Export and send the public key to the server for sharing with others
    const exportedPublicKey = await exportPublicKey(publicKey);
    console.log("[INFO] Sharing public key with the other participant");
    socket.emit("share_public_key", {
        room_id: room_id,
        public_key: Array.from(new Uint8Array(exportedPublicKey)),
        username: username
    });
});

// Receive and store public key from another user
socket.on("receive_public_key", async (data) => {
    const publicKeyData = new Uint8Array(data.public_key);
    otherUserPublicKey = await importPublicKey(publicKeyData.buffer);
    console.log(`[INFO] Received public key from '${data.username}'`);
});

// Receive an encrypted message or system message
socket.on("receive_message", async (data) => {
    console.log(`[INFO] Received message from user '${data.username}'`);
    if (data.type === "system") {
        // Handle the system message (e.g., user has left the room)
        const messageElement = document.createElement("div");
        messageElement.classList.add("message", "system-message");
        messageElement.innerHTML = `<em>${data.username} ${data.message}</em>`;
        chatMessages.appendChild(messageElement);
        scrollToBottom();
    } else {
        const encryptedAESKey = new Uint8Array(data.aes_key);
        const iv = new Uint8Array(data.iv);
        const encryptedMessage = new Uint8Array(data.message);

        // Step 1: Decrypt the AES key with your private RSA key
        const decryptedAESKey = await decryptAESKey(encryptedAESKey, privateKey);

        // Step 2: Import the decrypted AES key
        const aesKey = await importAESKey(decryptedAESKey);

        // Step 3: Decrypt the message with AES
        const decryptedMessage = await decryptWithAES(encryptedMessage, iv, aesKey);

        // Step 4: Display the decrypted message
        const messageElement = document.createElement("div");
        messageElement.classList.add("message");
        messageElement.innerHTML = `<strong>${data.username}:</strong> ${decryptedMessage}`;
        chatMessages.appendChild(messageElement);
        scrollToBottom();
    }
});


// Handle errors from the server
socket.on("error", (data) => {
    console.error("[ERROR] Server error:", data.message || "An error occurred.");
    alert(data.message || "An error occurred.");
});
