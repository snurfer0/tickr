/** Colours for a rising and a falling price. */
export interface Scheme {
    id: string
    name: string
    up: string
    down: string
}

export const SCHEMES: Scheme[] = [
    { id: "classic", name: "Classic", up: "#4ade80", down: "#f87171" },
    { id: "vivid", name: "Vivid", up: "#00e676", down: "#ff1744" },
    { id: "pastel", name: "Pastel", up: "#a7f3d0", down: "#fecaca" },
    { id: "ocean", name: "Ocean", up: "#38bdf8", down: "#fb923c" },
    { id: "inverse", name: "Red up", up: "#f87171", down: "#4ade80" },
    { id: "mono", name: "Mono", up: "", down: "" },
    { id: "custom", name: "Custom", up: "", down: "" },
]

/**
 * The two colours to draw with; an empty string means "use the normal text colour" (Mono).
 * An unknown id, e.g. from a newer version's settings, falls back to Classic.
 */
export function schemeColors(id: string, customUp: string, customDown: string): { up: string; down: string } {
    if (id === "custom") return { up: customUp, down: customDown }
    const scheme = SCHEMES.find((s) => s.id === id) ?? SCHEMES[0]
    return { up: scheme?.up ?? "", down: scheme?.down ?? "" }
}
