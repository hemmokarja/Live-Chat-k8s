const messageInput = document.getElementById("message-input");
const chatMessages = document.getElementById("chat-messages");
const sendBtn = document.getElementById("send-btn");
const leaveRoomBtn = document.getElementById("leave-room-btn");

// Initialize the socket connection
const socket = io("ws://localhost:5002", {
    query: { username: username }
});

// Get other user's name from session storage
const other_user = sessionStorage.getItem("other_user");
document.getElementById("chat-other-user").textContent = other_user;

// Encryption
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

const encryptMessage = async (message, key) => {
    const encoder = new TextEncoder();
    const data = encoder.encode(message);
    const ciphertext = await window.crypto.subtle.encrypt(
        { name: "RSA-OAEP" },
        key, // Public key
        data
    );
    return ciphertext;
};

const decryptMessage = async (ciphertext, key) => {
    const decrypted = await window.crypto.subtle.decrypt(
        { name: "RSA-OAEP" },
        key, // Private key
        ciphertext
    );
    const decoder = new TextDecoder();
    return decoder.decode(decrypted);
};

// Function to export the public key for sharing
const exportPublicKey = async (key) => {
    return window.crypto.subtle.exportKey("spki", key);
};

// Function to import a public key from another user
const importPublicKey = async (keyData) => {
    return window.crypto.subtle.importKey(
        "spki",
        keyData,
        { name: "RSA-OAEP", hash: { name: "SHA-256" } },
        true, // Can be used for encrypting messages
        ["encrypt"]
    );
};

// Send an encrypted message to the server
const sendMessage = async () => {
    const message = messageInput.value.trim();
    if (message && otherUserPublicKey) {
        // Encrypt the message with the recipient's public key
        const encryptedMessage = await encryptMessage(message, otherUserPublicKey);

        // Send encrypted message as a Uint8Array to the server
        socket.emit("send_message", {
            room_id: room_id,
            message: Array.from(new Uint8Array(encryptedMessage)),
            username: username
        });
        messageInput.value = "";

        // Append the message to your own chat window (plaintext)
        const messageElement = document.createElement("div");
        messageElement.classList.add("message");
        messageElement.innerHTML = `<strong>${username}:</strong> ${message}`;
        chatMessages.appendChild(messageElement);
        scrollToBottom(); // Scroll the chat to the bottom
    } else {
        console.error("No public key for the recipient");
    }
};

// Helper function for error handling
const handleError = (message) => {
    console.error(message);
    alert(message || "An unexpected error occurred.");
};

// Scroll chat to the latest message
const scrollToBottom = () => {
    chatMessages.scrollTop = chatMessages.scrollHeight;
};

// Event handler for sending a message when the "Send" button is clicked
sendBtn.addEventListener("click", sendMessage);

// Event handler for sending a message when pressing "Enter" in the input field
messageInput.addEventListener("keypress", (e) => {
    if (e.key === "Enter") {
        sendMessage();
    }
});

// Handle Back to Lobby button click
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

// Receive an encrypted message and decrypt it
socket.on("receive_message", async (data) => {
    const encryptedMessage = new Uint8Array(data.message);
    const sender = data.username;

    // Decrypt the message with your private key
    const decryptedMessage = await decryptMessage(encryptedMessage, privateKey);

    // Display the decrypted message in the chat
    const messageElement = document.createElement("div");
    messageElement.classList.add("message");
    messageElement.innerHTML = `<strong>${sender}:</strong> ${decryptedMessage}`;
    chatMessages.appendChild(messageElement);
    scrollToBottom();
});

// Handle errors from the server
socket.on("error", (data) => {
    console.error("Error:", data.message || "An error occurred.");
    alert(data.message || "An error occurred.");
});
