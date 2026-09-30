// The one network helper, shared by the widget and its settings. It uses the XMLHttpRequest that
// Plasma's QML engine provides; there is no fetch() there.

interface Xhr {
    readyState: number
    status: number
    responseText: string
    onreadystatechange: (() => void) | null
    open(method: string, url: string): void
    setRequestHeader(name: string, value: string): void
    send(body?: string): void
}
declare const XMLHttpRequest: { new (): Xhr; readonly DONE: number }

/**
 * GET, or POST when `body` is given (as JSON). `done` gets the HTTP status (0 when the request
 * never got an answer) and the parsed JSON body, or null when there is none.
 */
export function request(url: string, body: string, done: (status: number, json: unknown) => void): void {
    const xhr = new XMLHttpRequest()
    xhr.onreadystatechange = () => {
        if (xhr.readyState !== XMLHttpRequest.DONE) return
        let json: unknown = null
        // `catch (_error)` rather than a bare `catch`: the QML engine predates optional catch binding.
        try {
            json = JSON.parse(xhr.responseText)
        } catch (_error) {
            // Not JSON (an HTML error page, an empty body): callers get null.
        }
        done(xhr.status, json)
    }
    xhr.open(body === "" ? "GET" : "POST", url)
    if (body !== "") xhr.setRequestHeader("Content-Type", "application/json")
    xhr.send(body === "" ? undefined : body)
}
