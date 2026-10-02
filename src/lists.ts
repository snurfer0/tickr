import { formatCoins, parseCoins } from "./coins.ts"

/** A named set of coins. The ticker shows one list at a time. */
export interface CoinList {
    /** Empty for the list nobody has named yet. */
    name: string
    /** The list's coins as text, in the form `formatCoins` writes. */
    coins: string
}

/**
 * A line that starts a list: `# [Name]`. Written as a comment, so a version of Tickr without lists
 * reads the same text as one list of every coin.
 */
const HEADER = /^#\s*\[(.*)\]\s*$/
const NAME_LENGTH = 24

function cleanName(name: string): string {
    return name
        .replace(/[[\]\n]/g, " ")
        .trim()
        .slice(0, NAME_LENGTH)
}

/**
 * Splits the stored text into its lists; the coins after a `# [Name]` line belong to that list.
 * Text without such a line is one unnamed list, and there is always at least one.
 */
export function parseLists(text: string): CoinList[] {
    const lists: CoinList[] = []
    let name = ""
    let named = false
    let rows: string[] = []
    const close = () => {
        const coins = formatCoins(parseCoins(rows.join("\n")))
        if (named || coins !== "") lists.push({ name, coins })
    }
    for (const row of text.split("\n")) {
        const header = HEADER.exec(row.trim())
        if (header === null) {
            rows.push(row)
            continue
        }
        close()
        name = cleanName(header[1] ?? "")
        named = true
        rows = []
    }
    close()
    return lists.length === 0 ? [{ name: "", coins: "" }] : lists
}

/** The lists as text: what `parseLists` reads back. A single unnamed list is written without a header. */
export function formatLists(lists: CoinList[]): string {
    const [only] = lists
    if (lists.length === 1 && only !== undefined && only.name === "") return only.coins
    return lists.map((l) => (l.coins === "" ? `# [${l.name}]` : `# [${l.name}]\n${l.coins}`)).join("\n")
}

/** The text with the coins of the list at `index` replaced; unchanged for an index out of range. */
export function setListCoins(text: string, index: number, coins: string): string {
    const lists = parseLists(text)
    const target = lists[index]
    if (target === undefined) return text
    target.coins = formatCoins(parseCoins(coins))
    return formatLists(lists)
}

/** The text with a new, empty list at the end. */
export function addList(text: string, name: string): string {
    return formatLists([...parseLists(text), { name: cleanName(name), coins: "" }])
}

/** The text with the list at `index` renamed; unchanged for an index out of range. */
export function renameList(text: string, index: number, name: string): string {
    const lists = parseLists(text)
    const target = lists[index]
    if (target === undefined) return text
    target.name = cleanName(name)
    return formatLists(lists)
}

/** The text without the list at `index` and its coins; the last list cannot be removed. */
export function removeList(text: string, index: number): string {
    const lists = parseLists(text)
    if (lists.length < 2 || lists[index] === undefined) return text
    lists.splice(index, 1)
    return formatLists(lists)
}
