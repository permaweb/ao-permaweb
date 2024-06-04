/**
 * Filters the provided messages array to return only those messages that have a matching tag.
 *
 * @param {Array} messages - The array of message objects to filter.
 * @param {string} tagName - The tag name to match in the messages.
 * @returns {Array} An array of messages that have the specified tag.
 */
export function findMessageByTag(messages, tagName) {
    if (messages && messages.length) {
        return messages.filter(m =>
            m.Tags && m.Tags.length && m.Tags.some(t => t.name === tagName)
        )
    }
    return [];
}

/**
 * Filters the provided messages array to return only those messages that have a matching target.
 *
 * @param {Array} messages - The array of message objects to filter.
 * @param {string} target - The target to match in the messages.
 * @returns {Array} An array of messages that have the specified target.
 */
export function findMessageByTarget(messages, target) {
    if (messages && messages.length) {
        return messages.filter(m => m.Target === target)
    }
    return []
}

/**
 * Retrieves the value of a specific tag from a message object.
 *
 * @param {Object} msg - The message object to search for the tag.
 * @param {string} tagName - The name of the tag to find.
 * @returns {string|null} The value of the tag if found, null otherwise.
 */
export function getTag(msg, tagName) {
    return msg?.Tags?.find(t => t.name === tagName)?.value ?? null;
}

export function stripAnsiCodes(str) {
    // Regular expression to match ANSI escape codes
    const ansiRegex = /\x1B\[[0-?]*[ -/]*[@-~]/g;
    return str.replace(ansiRegex, '');
}

export function logSendResult(sendResult, label) {
    console.log(`SEND RESULT: ${label}`);
    if (sendResult?.Output) {
        console.log('---OUTPUT: (printed)', sendResult.Output)
    } else {
        console.log('---ERROR:', sendResult)
    }
    if (sendResult.Messages && sendResult.Messages.length > 0) {
        sendResult.Messages.forEach((m, index) => {
            console.log(`---MESSAGE INDEX ${index}`)
            console.log(`----TAGS:`)
            m.Tags.forEach(t => {
                console.log(t)
            })
            console.log(`----DATA:`)
            console.log(m.Data)
        })
    }
}
