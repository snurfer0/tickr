// API responses arrive as `unknown`; these narrow them without trusting their shape.

export function isRecord(value: unknown): value is Record<string, unknown> {
    return typeof value === "object" && value !== null && !Array.isArray(value)
}

/** Number from a JSON number or numeric string; NaN for anything else. */
export function toNumber(value: unknown): number {
    if (typeof value === "number") return value
    if (typeof value === "string" && value.trim() !== "") return Number(value)
    return Number.NaN
}

export function toText(value: unknown): string {
    return typeof value === "string" ? value : ""
}
