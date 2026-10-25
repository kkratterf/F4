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
        guard count > 0, columns > 0 else { return 0 }
        let index = min(max(index, 0), count - 1)
        switch direction {
        case .left:
            return max(index - 1, 0)
        case .right:
            return min(index + 1, count - 1)
        case .up:
            return index - columns >= 0 ? index - columns : index
        case .down:
            if index + columns < count { return index + columns }
            // A shorter last row below: go to its last item.
            let lastRow = (count - 1) / columns
            return index / columns < lastRow ? count - 1 : index
        }
    }
}
