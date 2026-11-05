/// A move of the selection in the meme grid.
public enum GridDirection: Sendable {
    case left, right, up, down
}

/// Moves a selection through a grid laid out row by row.
public enum GridNavigation {
    /// The index after moving `direction` from `index` in a grid of `count`
    /// items and `columns` columns.
    ///
    /// Left and right step through the items and wrap between rows. Up and
    /// down move by a whole row; down from the second-to-last row lands on
    /// the last item when the last row is shorter. Moves past the edges stay put.
    public static func move(_ direction: GridDirection, from index: Int, count: Int, columns: Int) -> Int {
        move(direction, from: index, sections: [count], columns: columns)
    }

    /// The index after moving `direction` from `index` in a grid split into
    /// sections of `sections` items each (Favourites, then the rest): every
    /// section starts on a new row. Indices run through all sections in order.
    ///
    /// Inside a section it moves like `move(_:from:count:columns:)`. Up from
    /// a section's first row goes to the last row of the section above, in
    /// the same column or the last item of a shorter row; down from its last
    /// row goes to the first row of the section below. Empty sections are skipped.
    public static func move(_ direction: GridDirection, from index: Int, sections: [Int], columns: Int) -> Int {
        let sizes = sections.map { max($0, 0) }
        let count = sizes.reduce(0, +)
        guard count > 0, columns > 0 else { return 0 }
        let index = min(max(index, 0), count - 1)
        switch direction {
        case .left:
            return max(index - 1, 0)
        case .right:
            return min(index + 1, count - 1)
        case .up, .down:
            break
        }
        // Find the section of `index` and the position inside it.
        var section = 0
        var start = 0
        while index >= start + sizes[section] {
            start += sizes[section]
            section += 1
        }
        let size = sizes[section]
        let local = index - start
        let column = local % columns
        let lastRow = (size - 1) / columns
        if direction == .up {
            if local - columns >= 0 { return index - columns }
            // The last row of the nearest non-empty section above.
            var above = section - 1
            var aboveStart = start
            while above >= 0 {
                aboveStart -= sizes[above]
                if sizes[above] > 0 { break }
                above -= 1
            }
            guard above >= 0 else { return index }
            let aboveSize = sizes[above]
            let rowStart = (aboveSize - 1) / columns * columns
            return aboveStart + min(rowStart + column, aboveSize - 1)
        }
        if local + columns < size { return index + columns }
        // A shorter last row below in the same section: go to its last item.
        if local / columns < lastRow { return start + size - 1 }
        // The first row of the nearest non-empty section below.
        var below = section + 1
        var belowStart = start + size
        while below < sizes.count, sizes[below] == 0 { below += 1 }
        guard below < sizes.count else { return index }
        for skipped in (section + 1)..<below { belowStart += sizes[skipped] }
        return belowStart + min(column, sizes[below] - 1)
    }
}
