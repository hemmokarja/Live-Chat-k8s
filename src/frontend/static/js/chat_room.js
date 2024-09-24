const messageInput = document.getElementById("message-input");
const chatMessages = document.getElementById("chat-messages");
const sendBtn = document.getElementById("send-btn");
const leaveRoomBtn = document.getElementById("leave-room-btn");

// Initialize the socket connection
const socket = io("ws://localhost:5002", {
    query: { username: username }
});

// Emit send message event to the server
const sendMessage = () => {
    const message = messageInput.value.trim();
    if (message) {
        socket.emit("send_message", {
            room_id: room_id,
            message: message,
            username: username
        });
        messageInput.value = "";  // Clear input field after sending
    }
};

// Scroll chat to the latest message
const scrollToBottom = () => {
    chatMessages.scrollTop = chatMessages.scrollHeight;
};

// Event handler for sending a message when the "Send" button is clicked
sendBtn.addEventListener("click", sendMessage);

// Event handler for sending a message when pressing "Enter" in the input field
messageInput.addEventListener("keypress", (e) => {
    if (e.key === 'Enter') {
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

// Handle successful room join
socket.on("join_room_success", (data) => {
    console.log(data.message);
});

// Handle room join failure and redirect
socket.on("join_room_failure", (data) => {
    window.location.href = "/unauthorized";
});

// Receive message from the server and append it to the chat
socket.on("receive_message", (data) => {
    const messageElement = document.createElement("div");
    messageElement.classList.add("message");
    messageElement.innerHTML = `<strong>${data.username}:</strong> ${data.message}`;
    chatMessages.appendChild(messageElement);
    scrollToBottom();
});

// Handle errors from the server
socket.on("error", (data) => {
    console.error("Error:", data.message || "An error occurred.");
    alert(data.message || "An error occurred.");
});

// Helper function for error handling
const handleError = (message) => {
    console.error(message);
    alert(message || "An unexpected error occurred.");
};
