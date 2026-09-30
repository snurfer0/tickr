const SUBSCRIPT = "₀₁₂₃₄₅₆₇₈₉"

/** `EKpQGSJt…zcjm` style: long contract addresses shortened to their ends. */
export function shortAddress(address: string): string {
    return address.length > 12 ? `${address.slice(0, 4)}…${address.slice(-4)}` : address
}

function group(digits: string): string {
    return digits.replace(/\B(?=(\d{3})+(?!\d))/g, ",")
}

function trimZeros(text: string): string {
    return text.includes(".") ? text.replace(/0+$/, "").replace(/\.$/, "") : text
}

/**
 * Four significant digits at most, in the shortest readable form:
 * 83,759 · 2,694.75 · 119.52 · 0.2557 · 0.0₅3883 (five zeros after the point, the way DEX screens write it).
 */
export function price(value: number): string {
    if (!(value > 0) || !Number.isFinite(value)) return "—"
    if (value >= 10000) return group(String(Math.round(value)))
    if (value >= 1) {
        const [whole = "0", cents = "00"] = value.toFixed(2).split(".")
        return `${group(whole)}.${cents}`
    }
    // Round first, so 0.00009999… becomes 0.0001 and not a subscript form.
    const rounded = Number(value.toPrecision(4))
    if (rounded >= 0.0001) return trimZeros(rounded.toPrecision(4))
    const [mantissa = "0", exponent = "0"] = rounded.toExponential(3).split("e")
    const zeros = -Number(exponent) - 1
    const subscript = String(zeros)
        .split("")
        .map((digit) => SUBSCRIPT[Number(digit)] ?? "")
        .join("")
    return `0.0${subscript}${trimZeros(mantissa).replace(".", "")}`
}

/** +0.75% · −12.3% · +250% */
export function percent(change: number): string {
    if (!Number.isFinite(change)) return "—"
    const size = Math.abs(change)
    const sign = change > 0 ? "+" : change < 0 ? "−" : ""
    const digits = size >= 100 ? size.toFixed(0) : size.toFixed(size >= 10 ? 1 : 2)
    return `${sign}${digits}%`
}

/** Funding as the exchange quotes it: percent per hour, four decimals. */
export function funding(perHour: number): string {
    if (!Number.isFinite(perHour)) return "—"
    const sign = perHour > 0 ? "+" : perHour < 0 ? "−" : ""
    return `${sign}${Math.abs(perHour).toFixed(4)}%/h`
}
