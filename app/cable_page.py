# RIGa&AI 2026 - pure page selection logic
"""Pure helpers for selecting the rows of a single cable page.

Kept free of any GUI dependency so the parsing logic can be unit-tested and
reused independently of the Treeview widget.
"""

from typing import List

from constants import PAGE_DIRECTIVE


def select_page_rows(rows: List[list], page_name: str) -> List[list]:
    """Return the rows to display for one selected page.

    The result is the header directives that precede the first PAGE marker
    (deduplicated by directive name, last value wins) followed by the PAGE
    marker row of ``page_name`` and its data rows, up to the next empty row
    or PAGE marker.

    Args:
        rows: full table as a list of row lists (cell values).
        page_name: the page to extract.
    """
    header_rows: List[list] = []
    header_index = {}          # directive name -> index in header_rows
    page_rows: List[list] = []
    in_target_page = False
    seen_first_page = False

    for row in rows:
        is_empty = not any(cell and str(cell).strip() for cell in row)
        first = str(row[0]).strip() if row and row[0] else ""
        directive = first.upper()

        if in_target_page:
            # The page section ends at an empty row or the next PAGE marker.
            if is_empty or directive == PAGE_DIRECTIVE:
                break
            page_rows.append(row)
            continue

        if directive == PAGE_DIRECTIVE:
            seen_first_page = True
            value = str(row[1]).strip() if len(row) > 1 and row[1] else ""
            if value == page_name:
                in_target_page = True
                page_rows.append(row)  # include the PAGE marker row
            continue

        # Header region (before the first PAGE): keep unique directives.
        if not seen_first_page and not is_empty:
            if directive and directive in header_index:
                header_rows[header_index[directive]] = row
            else:
                if directive:
                    header_index[directive] = len(header_rows)
                header_rows.append(row)

    return header_rows + page_rows
