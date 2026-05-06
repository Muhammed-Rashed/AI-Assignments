class GameController:
    def __init__(self, janus):
        self.janus = janus
        self.board = None
        self.current_turn = "Attacker"
        self.game_state = "ongoing"

        self.player_role = None
        self.ai_depth = 3

    def init_board(self, board):
        self.board = board
        self.current_turn = "Attacker"
        self.game_state = "ongoing"

    def turn_to_prolog(self):
        return "a" if self.current_turn == "Attacker" else "d"

    def switch_turn(self):
        self.current_turn = "Defender" if self.current_turn == "Attacker" else "Attacker"

    def get_valid_moves(self, board, r, c):
        result = self.janus.query_once(
            "valid_moves(Board, R, C, Turn, Moves)",
            {"Board": board, "R": r, "C": c, "Turn": self.turn_to_prolog()}
        )

        if result and "Moves" in result:
            return [tuple(m) for m in (result["Moves"] or [])]

        return []

    def apply_move(self, board, sr, sc, tr, tc):
        result = self.janus.query_once(
            "apply_move(Board, R1, C1, R2, C2, Turn, NewBoard, State)",
            {"Board": board, "R1": sr, "C1": sc, "R2": tr, "C2": tc, "Turn": self.turn_to_prolog()}
        )

        if not result or "NewBoard" not in result:
            return None, None

        self.board = result["NewBoard"]
        self.game_state = result.get("State", "ongoing")

        self.switch_turn()
        return self.board, self.game_state

    def is_ai_turn(self):
        if self.player_role is None:
            return False

        if self.player_role == 0:
            return self.current_turn == "Defender"
        else:
            return self.current_turn == "Attacker"

    def ai_move(self, board):
        result = self.janus.query_once(
            "ai_move(Board, Turn, Depth, Width, NewBoard, GameState)",
            {
                "Board": board,
                "Turn": self.turn_to_prolog(),
                "Depth": self.ai_depth,
                "Width": 5
            }
        )

        if not result or result.get("NewBoard") is None:
            return None, None

        self.board = result["NewBoard"]
        self.game_state = result.get("GameState", "ongoing")

        self.switch_turn()
        return self.board, self.game_state