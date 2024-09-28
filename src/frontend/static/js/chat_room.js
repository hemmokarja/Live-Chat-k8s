const messageInput = document.getElementById("message-input");
const chatMessages = document.getElementById("chat-messages");
const sendBtn = document.getElementById("send-btn");
const leaveRoomBtn = document.getElementById("leave-room-btn");

// Initialize the socket connection
const socket = io("ws://localhost/socket.io", {
    query: { username: username }
});
// const socket = io("/", {
//     path: "/socket.io",
//     transports: ['websocket'],
//     query: { username: username }
// });

// Get other user's name from session storage
const other_user = sessionStorage.getItem("other_user");
document.getElementById("chat-other-user").textContent = other_user;


// RSA encryption for encrypting the AES key
let privateKey, publicKey;
let otherUserPublicKey;

async function generateKeyPair() {
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
    return window.crypto.subtle.exportKey("spki", key);
}

async function importPublicKey(keyData) {
    return window.crypto.subtle.importKey(
        "spki",
        keyData,
        { name: "RSA-OAEP", hash: { name: "SHA-256" } },
        true, // Can be used for encrypting messages
        ["encrypt"]
    );
}

async function exportAESKey(key) {
    return window.crypto.subtle.exportKey("raw", key);
}

async function importAESKey(keyData) {
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
    if (message && otherUserPublicKey) {
        // Step 1: Generate a symmetric AES key for encrypting the message
        const aesKey = await generateAESKey();

        // Step 2: Encrypt the message with AES
        const { iv, ciphertext } = await encryptWithAES(message, aesKey);

        // Step 3: Encrypt the AES key with the recipient's public RSA key
        const exportedAESKey = await exportAESKey(aesKey)
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

        // Step 5: Append the message to your own chat window (plaintext)
        const messageElement = document.createElement("div");
        messageElement.classList.add("message");
        messageElement.innerHTML = `<strong>${username}:</strong> ${message}`;
        chatMessages.appendChild(messageElement);
        scrollToBottom(); // Scroll the chat to the bottom
    } else {
        console.error("No message or public key for the recipient");
    }
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
    socket.emit("leave_room", { username: username, room_id: room_id });
    window.location.href = "/lobby";
});


// Socket event listeners

// When connected, join the room
socket.on("connect", () => {
    socket.emit("join_room", { username: username, room_id: room_id });
});

// Handle room join failure and redirect
socket.on("join_room_failure", (data) => {
    window.location.href = "/unauthorized";
});

// Generate keys and share public key upon joining the room
socket.on("join_room_success", async (data) => {
    console.log(data.message);

    // Generate the RSA key pair for this user
    const keyPair = await generateKeyPair();
    privateKey = keyPair.privateKey;
    publicKey = keyPair.publicKey;

    // Export and send the public key to the server for sharing with others
    const exportedPublicKey = await exportPublicKey(publicKey);
    socket.emit("share_public_key", {
        room_id: room_id,
        public_key: Array.from(new Uint8Array(exportedPublicKey))
    });
});

// Receive and store public key from another user
socket.on("receive_public_key", async (data) => {
    const publicKeyData = new Uint8Array(data.public_key);
    otherUserPublicKey = await importPublicKey(publicKeyData.buffer);
});

// Receive an encrypted message or system message
socket.on("receive_message", async (data) => {
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
    console.error("Error:", data.message || "An error occurred.");
    alert(data.message || "An error occurred.");
});
