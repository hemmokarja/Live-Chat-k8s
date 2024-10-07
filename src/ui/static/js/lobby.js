// Initialize the socket connection
const socket = io("ws://k8s-default-livechat-c766082308-918824972.eu-north-1.elb.amazonaws.com", {
    path: "/socket.io",
    transports: ["websocket"],
    query: { username: username },
});

// Get references to the DOM elements
const userList = document.getElementById("user-list");
const leaveLobbyBtn = document.getElementById("leave-lobby-btn");

// Track whether there's a pending chat request
let requestPending = false;

// Handle connection to the lobby
socket.on("connect", () => {
    console.log(`User '${username}' connected to the lobby`);
    socket.emit("join_lobby", { username: username });
});

// Handle disconnection from the server
socket.on("disconnect", () => {
    console.log("Disconnected from the server");
});

// Update the user list when a new list of users is received
socket.on("update_user_list", (users) => {
    userList.innerHTML = "";

    // Add the current user to the top of the list
    const currentUserLi = document.createElement("li");
    currentUserLi.classList.add("user-item");
    currentUserLi.innerText = `${username} (You)`;
    currentUserLi.style.fontWeight = "bold";
    userList.appendChild(currentUserLi);

    // Add other users to the list
    const otherUsers = users.filter((user) => user !== username);
    otherUsers.forEach((user) => {
        const li = document.createElement("li");
        li.classList.add("user-item");
        li.innerText = user;
        li.style.cursor = "pointer";

        // Handle click event on a user in the list
        li.addEventListener("click", () => {
        if (!requestPending) {
            requestPending = true;
            socket.emit("chat_request", {
                to_user: user,
                from_user: username,
            });
        } else {
            alert("You already have a pending chat request.");
        }
        });

        userList.appendChild(li);
    });
});

// Handle incoming chat request
socket.on("chat_request", (data) => {
    const fromUser = data.from_user;
    const accept = confirm(`User ${fromUser} wants to chat with you. Accept?`);

    // Send a response to the chat request
    socket.emit("chat_response", {
        from_user: fromUser,
        to_user: username,
        accepted: accept,
    });
});

// Handle the response to a chat request
socket.on("chat_response", (data) => {
    if (data.accepted) {
        sessionStorage.setItem("other_user", data.other_user);
        // Redirect to the chat room
        requestPending = false;
        window.location.href = `/chat_room?room_id=${data.room_id}`;
    } else {
        alert(data.message || "Your chat request was declined.");
        requestPending = false;
    }
});

// Handle leaving the lobby
leaveLobbyBtn.addEventListener("click", () => {
    socket.emit("leave_server", { username: username });
    window.location.href = "/";
});

// Handle connection errors
socket.on("connect_error", () => {
     alert("Connection failed. Please try again later.");
});

// Handle any server errors
socket.on("error", (errorMessage) => {
    console.error(errorMessage);
    alert("An error occurred. Please try again.");
});
