// Load this script using the "User JavaScript and CSS" browser extension during an active video call.

/**
 * Filters messages from a list of users in the video call chat
 * @param {string[]} filtered_users An array of usernames in lowercase to be filtered out
 * @returns {void}
 */
function filter_users(filtered_users) {
    document.querySelectorAll("#chatPanel .ReactVirtualized__Grid__innerScrollContainer > span")
    .forEach(chat => {
        let user_name = chat.querySelector('div[class*="name--"] > span')?.textContent?.toLowerCase() ?? "";
        if (user_name.length > 0 && filtered_users.includes(user_name)) {
            chat.remove();
            console.log(`User '${user_name}': Message deleted!`);
        }
    });
}
window.addEventListener("load", (e) => {
    const interval_ms = 800;
    const filtered_users = ["lower case user name"];
    const intervalo = setInterval(() => {
        filter_users(filtered_users);
    }, interval_ms);
});
