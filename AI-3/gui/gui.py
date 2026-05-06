import pygame
import sys
import janus_swi as janus
janus.consult("../api.pl")
pygame.init()
pygame.mixer.init()

BOARD_SIZE = 9
UI_HEIGHT = 40
WIDTH = 737
HEIGHT = WIDTH + UI_HEIGHT
SQUARE_SIZE = WIDTH // BOARD_SIZE

LIGHT_CYAN = (170, 215, 235)
DARK_CYAN = (120, 175, 205)
LINE_COLOR = (80, 60, 40) 

UI_BG = (235, 235, 235)
TEXT_COLOR = (0, 0, 0)

RESET_COLOR = (220, 220, 220)
RESET_BORDER = (80, 80, 80)

HIGHLIGHT = (255, 255, 0)
MOVE_HINT = (120, 255, 120)
LAST_MOVE_COLOR = (120, 180, 255)

screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Hnefatafl")

font = pygame.font.SysFont(None, 22)
clock = pygame.time.Clock()


class Piece:
    def __init__(self, p_type, image):
        self.type = p_type
        self.image = image


class Game:
    def __init__(self):
        # Core Game State
        self.state = "menu"
        self.game_state = "ongoing"
        self.current_turn = "Attacker"
        self.player_role = None
        self.ai_difficulty = None
        
        # Board & Logic
        self.board = [[None for _ in range(BOARD_SIZE)] for _ in range(BOARD_SIZE)]
        self.center = BOARD_SIZE // 2
        self.special_squares = {(0,0), (0,10), (10,0), (10,10), (self.center, self.center)}
        self.selected = None
        self.valid_moves = []
        self.last_move = None

        # Animation State
        self.animating = False
        self.anim_piece = None
        self.anim_start = None
        self.anim_end = None
        self.anim_progress = 0

        # Game Over Logic
        self.end_timer = None
        self.show_end_screen = False
        self.win_sound_played = False
        self.victory_sound_played = False

        # Initialize Assets and UI
        self.load_assets()
        self.setup_buttons()
        self.init_board()

    def load_assets(self):
        # Backgrounds
        self.menu_bg = self._load_img("menu.png", (WIDTH, HEIGHT))
        self.ai_menu = self._load_img("Diff.png", (WIDTH, HEIGHT))
        self.role_bg = self._load_img("Role.png", (WIDTH, HEIGHT))
        self.board_bg = self._load_img("board.png", (WIDTH, WIDTH))
        self.dwins_bg = self._load_img("dwins.jpg", (WIDTH, HEIGHT))
        self.awins_bg = self._load_img("awins.jpg", (WIDTH, HEIGHT))
        
        # Sounds
        self.move_sound = pygame.mixer.Sound("move.wav")
        self.move_sound.set_volume(0.6)
        self.capture_sound = pygame.mixer.Sound("capture.wav")
        self.win_sound = pygame.mixer.Sound("win.wav")
        self.victory_sound = pygame.mixer.Sound("victory.wav")
        self.victory_sound.set_volume(0.4)
        
        # Pieces
        self.load_images()

    def setup_buttons(self):
        # Clickable areas
        # Main Menu & Mode
        self.btn_pvp = pygame.Rect(283, 455, 280, 70)
        self.btn_pvai = pygame.Rect(284, 289, 243, 70)
        
        # Difficulty Menu
        self.btn_easy = pygame.Rect(282, 277, 240, 65)
        self.btn_medium = pygame.Rect(282, 432, 240, 66)
        self.btn_hard = pygame.Rect(282, 587, 240, 65)
        
        # Role Selection
        self.btn_att = pygame.Rect(282, 288, 237, 66)
        self.btn_def = pygame.Rect(282, 445, 257, 66)
        
        # In-Game & End Screen
        self.reset_button = pygame.Rect(WIDTH - 130, 7, 120, 26)
        self.btn_play_again = pygame.Rect(205, 587, 330, 68)

        # Centered HUD Buttons (Legacy/Alternative)
        self.attacker_button = pygame.Rect(WIDTH//2 - 120, HEIGHT//2 - 40, 240, 40)
        self.defender_button = pygame.Rect(WIDTH//2 - 120, HEIGHT//2 + 20, 240, 40)
    
    def load_images(self):
        self.pieces_img = {
            "attacker": self._prepare_piece("attacker.png"),
            "defender": self._prepare_piece("defender.png"),
            "king":     self._prepare_piece("king.png", is_king=True)
        }

    def _load_img(self, path, scale):
        img = pygame.image.load(path)
        return pygame.transform.smoothscale(img, scale)
    
    def _prepare_piece(self, path, is_king=False):
        img = pygame.image.load(path)
        scale = min(SQUARE_SIZE / img.get_width(), SQUARE_SIZE / img.get_height())
        extra = 2 if is_king else 0
        new_size = (int(img.get_width() * scale + extra), int(img.get_height() * scale + extra))
        return pygame.transform.smoothscale(img, new_size)
    

    
    # --------- Board and State Helpers---------
    def init_board(self):
        self.board = [[None for _ in range(BOARD_SIZE)] for _ in range(BOARD_SIZE)]

        c = self.center
        self.board[c][c] = Piece("king", self.pieces_img["king"])

        defenders = [
            (c-1,c),(c+1,c),(c,c-1),(c,c+1),
            (c-2,c),(c+2,c),(c,c-2),(c,c+2),
            (c-1,c-1),(c-1,c+1),(c+1,c-1),(c+1,c+1)
        ]

        for r,c in defenders:
            self.board[r][c] = Piece("defender", self.pieces_img["defender"])

        attackers = [
            (0,2),(0,3),(0,4),(0,5),(0,6),
            (8,2),(8,3),(8,4),(8,5),(8,6),
            (2,0),(3,0),(4,0),(5,0),(6,0),
            (2,8),(3,8),(4,8),(5,8),(6,8),
            (1,4),(7,4),
            (4,1),(4,7)
        ]

        for r,c in attackers:
            self.board[r][c] = Piece("attacker", self.pieces_img["attacker"])


    def in_bounds(self,r,c):
        return 0 <= r < BOARD_SIZE and 0 <= c < BOARD_SIZE
                
    def count_pieces(self, board):
        count = 0
        for row in board:
            for cell in row:
                if cell is not None:
                    count += 1
        return count
    
    def turn_to_prolog(self):
        return "a" if self.current_turn == "Attacker" else "d"
    
    def prolog_board(self):
        def convert(cell):
            if cell is None:
                return "e"
            return cell.type[0]
        return [[convert(c) for c in row] for row in self.board]
    
    def from_prolog_board(self, board):
        def make(v):
            if v == "a":
                return Piece("attacker", self.pieces_img["attacker"])
            if v == "d":
                return Piece("defender", self.pieces_img["defender"])
            if v == "k":
                return Piece("king", self.pieces_img["king"])
            return None

        return [[make(c) for c in row] for row in board]
    

    
    # -----------Animation -----------
    def update_animation(self):
        if not self.animating:
            return

        speed = 0.1  # animation speed
        self.anim_progress += speed

        if self.anim_progress >= 1:
            self.animating = False
            self.anim_progress = 1

            # apply final board AFTER animation
            self.board = self.pending_board
            self.game_state = self.pending_state

            # if game ended → start timer
            if self.game_state in ["attackers_win", "defenders_win"]:
                self.end_timer = pygame.time.get_ticks()

            if self.game_state == "ongoing":
                self.current_turn = (
                    "Defender" if self.current_turn == "Attacker" else "Attacker"
                )
    


    # ---------- Drawing/Rendering --------
    def draw_menu(self):
        screen.blit(self.menu_bg, (0, 0))
        mouse_pos = pygame.mouse.get_pos()
        if self.btn_pvai.collidepoint(mouse_pos):
            pygame.draw.rect(screen, (220, 200, 150), self.btn_pvai, 3, border_radius=8)

        if self.btn_pvp.collidepoint(mouse_pos):
            pygame.draw.rect(screen, (220, 200, 150), self.btn_pvp, 3, border_radius=8)

    def draw_ai_menu(self):
        screen.blit(self.ai_menu, (0, 0))
        mouse_pos = pygame.mouse.get_pos()
        if self.btn_easy.collidepoint(mouse_pos):
            pygame.draw.rect(screen, (220, 200, 150), self.btn_easy, 3, border_radius=8)

        if self.btn_medium.collidepoint(mouse_pos):
            pygame.draw.rect(screen, (220, 200, 150), self.btn_medium, 3, border_radius=8)
            
        if self.btn_hard.collidepoint(mouse_pos):
            pygame.draw.rect(screen, (220, 200, 150), self.btn_hard, 3, border_radius=8)
            
    def draw_role_menu(self):
        screen.blit(self.role_bg, (0, 0))
        mouse_pos = pygame.mouse.get_pos()
        if self.btn_att.collidepoint(mouse_pos):
            pygame.draw.rect(screen, (220, 200, 150), self.btn_att, 3, border_radius=8)

        if self.btn_def.collidepoint(mouse_pos):
            pygame.draw.rect(screen, (220, 200, 150), self.btn_def, 3, border_radius=8)

    def draw_game_over(self):
        if self.game_state == "defenders_win":
            screen.blit(self.dwins_bg, (0, 0))
        elif self.game_state == "attackers_win":
            screen.blit(self.awins_bg, (0, 0))

        mouse_pos = pygame.mouse.get_pos()
        if self.btn_play_again.collidepoint(mouse_pos):
            pygame.draw.rect(screen, (220, 200, 150), self.btn_play_again, 3, border_radius=10)
    
    def draw_game_screen(self):
        self.draw_board()
        self.draw_pieces()
        self.draw_ui()

    def draw_ui(self):
        # Header Background
        pygame.draw.rect(screen, UI_BG, (0, 0, WIDTH, UI_HEIGHT))

        # Status Text & Sounds
        status_text = self._get_status_text()
        screen.blit(font.render(status_text, True, TEXT_COLOR), (10, 10))

        # Reset Button
        pygame.draw.rect(screen, RESET_COLOR, self.reset_button, border_radius=6)
        pygame.draw.rect(screen, RESET_BORDER, self.reset_button, 2, border_radius=6)
        reset_lbl = font.render("RESET", True, (0, 0, 0))
        screen.blit(reset_lbl, reset_lbl.get_rect(center=self.reset_button.center))

    def draw_board(self):
        # Base Image
        screen.blit(self.board_bg, (0, UI_HEIGHT))

        # Grid & Highlights
        for r in range(BOARD_SIZE):
            for c in range(BOARD_SIZE):
                rect = pygame.Rect(c * SQUARE_SIZE, r * SQUARE_SIZE + UI_HEIGHT, SQUARE_SIZE, SQUARE_SIZE)
                
                # Grid lines
                pygame.draw.rect(screen, LINE_COLOR, rect, 1)

                # Selected piece highlight
                if self.selected == (r, c):
                    pygame.draw.rect(screen, HIGHLIGHT, rect, 4)

                # Last move trace
                if self.last_move and (r, c) in self.last_move:
                    pygame.draw.rect(screen, LAST_MOVE_COLOR, rect, 3)

                # Move suggestions
                if (r, c) in self.valid_moves:
                    pygame.draw.circle(screen, MOVE_HINT, rect.center, 10)

    def draw_pieces(self):
        # Static Pieces (on board)
        for r in range(BOARD_SIZE):
            for c in range(BOARD_SIZE):
                # Don't draw the piece if it's currently sliding
                if self.animating and (r, c) == self.anim_start:
                    continue
                
                p = self.board[r][c]
                if p:
                    pos = self._get_piece_center(r, c)
                    screen.blit(p.image, p.image.get_rect(center=pos))

        # Animated Piece
        if self.animating:
            sr, sc = self.anim_start
            tr, tc = self.anim_end
            # Smooth interpolation
            curr_x = (sc + (tc - sc) * self.anim_progress) * SQUARE_SIZE + SQUARE_SIZE // 2
            curr_y = (sr + (tr - sr) * self.anim_progress) * SQUARE_SIZE + UI_HEIGHT + SQUARE_SIZE // 2
            screen.blit(self.anim_piece.image, self.anim_piece.image.get_rect(center=(curr_x, curr_y)))



    # ---------- AI Logic -----------
    def ai_move(self):
        # Setup Parameters
        board = self.prolog_board()
        turn = self.turn_to_prolog()
        depth = self.ai_difficulty
        
        # Difficulty Settings
        width_map = {1: 1000, 4: 10, 5: 5}
        width = width_map.get(depth, 5)

        # Execute Prolog Query
        result = janus.query_once(
            "ai_move(Board, Turn, Depth, Width, NewBoard, GameState)",
            {"Board": board, "Turn": turn, "Depth": depth, "Width": width}
        )

        if not result or result.get("NewBoard") is None:
            print(f"AI move failed. Result: {result}")
            return

        # Process Result & Group Board Changes
        old_count = self.count_pieces(self.board)
        new_board = self.from_prolog_board(result["NewBoard"])
        new_count = self.count_pieces(new_board)

        # Identify which piece moved by comparing boards
        for r in range(BOARD_SIZE):
            for c in range(BOARD_SIZE):
                # Start position: exists in old, gone in new
                if self.board[r][c] and not new_board[r][c]:
                    self.anim_start = (r, c)
                # End position: empty in old, filled in new
                if not self.board[r][c] and new_board[r][c]:
                    self.anim_end = (r, c)

        # Trigger Animation & Sound
        self._trigger_ai_animation(new_board, result.get("GameState", "ongoing"))
        
        if new_count < old_count:
            self.capture_sound.play()
        else:
            self.move_sound.play()

    def _trigger_ai_animation(self, next_board, next_state):
        sr, sc = self.anim_start
        self.anim_piece = self.board[sr][sc]
        self.last_move = (self.anim_start, self.anim_end)
        self.pending_board = next_board
        self.pending_state = next_state
        self.animating = True
        self.anim_progress = 0


    

    # -------- Clicks Handling ----------
    def handle_click(self, pos):
        # 1. MENU & NAVIGATION LOGIC
        # Game Over Screen
        if self.state == "game_over":
            if self.btn_play_again.collidepoint(pos):
                self.reset_to_initial_state()
            return

        # Global Reset Button (Handles ongoing or finished games)
        if self.reset_button.collidepoint(pos):
            self.reset_to_initial_state()
            return

        # Main Menu
        if self.state == "menu":
            if self.btn_pvp.collidepoint(pos):
                self.state = "game"
                self.init_board()
            elif self.btn_pvai.collidepoint(pos):
                self.state = "ai_menu"
            return

        # AI Difficulty Selection
        if self.state == "ai_menu":
            if self.btn_easy.collidepoint(pos):
                self.ai_difficulty = 1
                self.state = "role_menu"
            elif self.btn_medium.collidepoint(pos):
                self.ai_difficulty = 4
                self.state = "role_menu"
            elif self.btn_hard.collidepoint(pos):
                self.ai_difficulty = 5
                self.state = "role_menu"
            return

        # Role Selection
        if self.state == "role_menu":
            if self.btn_att.collidepoint(pos):
                self.player_role = 0
                self.state = "game"
                self.init_board()
            elif self.btn_def.collidepoint(pos):
                self.player_role = 1
                self.state = "game"
                self.init_board()
            return


        # 2. GAMEPLAY LOGIC
        # Block interactions if game is won/lost
        if self.game_state != "ongoing":
            return

        # Convert mouse click to board coordinates
        x, y = pos
        r = (y - UI_HEIGHT) // SQUARE_SIZE
        c = x // SQUARE_SIZE

        if not self.in_bounds(r, c):
            return

        board = self.prolog_board()


        # PIECE SELECTION
        if self.selected is None:
            piece = self.board[r][c]
            if piece is None:
                return

            # Enforce turn-based selection
            if self.current_turn == "Attacker" and piece.type != "attacker":
                return
            if self.current_turn == "Defender" and piece.type not in ["defender", "king"]:
                return

            self.selected = (r, c)
            result = janus.query_once(
                "valid_moves(Board, R, C, Turn, Moves)",
                {"Board": board, "R": r, "C": c, "Turn": self.turn_to_prolog()}
            )
            if result and "Moves" in result:
                moves = result.get("Moves") or []
                self.valid_moves = [tuple(m) for m in moves if m]
            else:
                self.valid_moves = []
            return

        # PIECE MOVEMENT
        sr, sc = self.selected
        tr, tc = r, c

        if (tr, tc) not in self.valid_moves:
            self.selected = None
            self.valid_moves = []
            return

        result = janus.query_once(
            "apply_move(Board, R1, C1, R2, C2, Turn, NewBoard, State)",
            {"Board": board, "R1": sr, "C1": sc, "R2": tr, "C2": tc, "Turn": self.turn_to_prolog()}
        )

        if result and "NewBoard" in result:
            old_count = self.count_pieces(self.board)
            new_board = self.from_prolog_board(result["NewBoard"])
            new_count = self.count_pieces(new_board)

            # Trigger Animation
            moving_piece = self.board[sr][sc]
            self.animating = True
            self.anim_piece = moving_piece
            self.anim_start = (sr, sc)
            self.anim_end = (tr, tc)
            self.last_move = ((sr, sc), (tr, tc))
            self.anim_progress = 0

            # Store pending results
            self.pending_board = new_board
            self.pending_state = result.get("State", "ongoing")

            # Sound effects
            if new_count < old_count:
                self.capture_sound.play()
            else:
                self.move_sound.play()

            self.selected = None
            self.valid_moves = []

    def reset_to_initial_state(self):
        self.player_role = None
        self.ai_difficulty = None
        self.game_state = "ongoing"
        self.current_turn = "Attacker"
        self.selected = None
        self.valid_moves = []
        self.last_move = None
        self.win_sound_played = False
        self.victory_sound_played = False
        self.state = "menu"
        self.end_timer = None
        self.show_end_screen = False


    
    #----Some Helper Functions----
    def _get_status_text(self):
        if self.game_state == "ongoing":
            return f"Turn: {self.current_turn}"
        
        if self.game_state == "attackers_win":
            if not self.win_sound_played:
                self.win_sound.play()
                self.win_sound_played = True
            return "Attackers Win!"
            
        if self.game_state == "defenders_win":
            if not self.victory_sound_played:
                self.victory_sound.play()
                self.victory_sound_played = True
            return "Defenders Win!"
        
        return "Game Over"

    def _get_piece_center(self, r, c):
        x = c * SQUARE_SIZE + SQUARE_SIZE // 2
        y = r * SQUARE_SIZE + UI_HEIGHT + SQUARE_SIZE // 2
        return (x, y)



    #----------Main Loop -----        
    def run(self):
        while True:
            for e in pygame.event.get():
                if e.type == pygame.QUIT:
                    pygame.quit()
                    sys.exit()
                if e.type == pygame.MOUSEBUTTONDOWN:
                    self.handle_click(pygame.mouse.get_pos())

            if self.state == "menu":
                self.draw_menu()
            elif self.state == "ai_menu":
                self.draw_ai_menu()
            elif self.state == "role_menu":
                self.draw_role_menu()
            elif self.state == "game_over":
                self.draw_game_over()
            elif self.state == "game":
                if self.end_timer:
                    current_time = pygame.time.get_ticks()
                    if current_time - self.end_timer >= 2500:
                        self.show_end_screen = True
                        self.state = "game_over"

                is_ai_turn = (
                    self.player_role is not None and
                    not self.animating and
                    self.game_state == "ongoing" and
                    (
                        (self.player_role == 0 and self.current_turn == "Defender") or
                        (self.player_role == 1 and self.current_turn == "Attacker")
                    )
                )
                if is_ai_turn:
                    self.ai_move()

                screen.fill((255, 255, 255))
                self.update_animation()
                self.draw_game_screen()

            pygame.display.flip()
            clock.tick(60)


if __name__ == "__main__":
    Game().run()