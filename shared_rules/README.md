shared_rules contains pure or nearly pure game logic.

Allowed:
- formulas
- balance rules
- progression rules
- boss mechanic logic
- drop calculations
- quest reward logic
- stat derivation

Forbidden:
- direct runtime ownership
- persistence
- scheduler ownership
- filesystem access
