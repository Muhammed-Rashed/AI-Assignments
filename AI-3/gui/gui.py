import pygame
import sys
import janus_swi as janus
janus.consult("api.pl")
pygame.init()
pygame.mixer.init()

BOARD_SIZE = 11
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

    def __init__(self):
        self.player_role = None
        self.ai_difficulty = None
        
        # stuff for game over screen
        self.end_timer = None
        self.show_end_screen = False

        # load win screens
        self.dwins_bg = pygame.image.load("gui/dwins.jpg")
        self.dwins_bg = pygame.transform.smoothscale(self.dwins_bg, (WIDTH, HEIGHT))

        self.awins_bg = pygame.image.load("gui/awins.jpg")
        self.awins_bg = pygame.transform.smoothscale(self.awins_bg, (WIDTH, HEIGHT))

        # Play Again button area (adjust if needed)
        self.btn_play_again = pygame.Rect(205, 587, 330, 68)
        # clickable areas for buttons
        # mode menu
        self.btn_pvai = pygame.Rect(284, 289, 243, 70)
        self.btn_pvp = pygame.Rect(283, 455, 280, 70)
        
        # Ai difficulty buttons
        self.btn_easy = pygame.Rect(282, 277, 240, 65)
        self.btn_medium = pygame.Rect(282, 432, 240, 66)
        self.btn_hard = pygame.Rect(282, 587, 240, 65)

        # role menu
        self.btn_att = pygame.Rect(282, 288, 237, 66)
        self.btn_def = pygame.Rect(282, 445, 257, 66)
        
        self.win_sound_played = False
        self.victory_sound_played = False
        self.game_state = "ongoing"
        self.move_sound = pygame.mixer.Sound("gui/move.wav")
        self.move_sound.set_volume(0.6)
        self.capture_sound = pygame.mixer.Sound("gui/capture.wav")
        self.win_sound = pygame.mixer.Sound("gui/win.wav")
        self.victory_sound = pygame.mixer.Sound("gui/victory.wav")
        self.victory_sound.set_volume(0.4)
        self.attacker_button = pygame.Rect(WIDTH//2 - 120, HEIGHT//2 - 40, 240, 40)
        self.defender_button = pygame.Rect(WIDTH//2 - 120, HEIGHT//2 + 20, 240, 40)

        self.easy_button = pygame.Rect(WIDTH//2 - 120, HEIGHT//2 - 60, 240, 40)
        self.medium_button = pygame.Rect(WIDTH//2 - 120, HEIGHT//2, 240, 40)
        self.hard_button = pygame.Rect(WIDTH//2 - 120, HEIGHT//2 + 60, 240, 40)

        self.pvp_button = pygame.Rect(WIDTH//2 - 120, HEIGHT//2 - 40, 240, 40)
        self.ai_button = pygame.Rect(WIDTH//2 - 120, HEIGHT//2 + 20, 240, 40)

        self.reset_button = pygame.Rect(WIDTH - 130, 7, 120, 26)
        # mode menu
        self.menu_bg = pygame.image.load("gui/menu.png")
        self.menu_bg = pygame.transform.smoothscale(self.menu_bg, (WIDTH, HEIGHT))
        
        # Ai menu
        
        self.ai_menu = pygame.image.load("gui/Diff.png")
        self.ai_menu = pygame.transform.smoothscale(self.ai_menu, (WIDTH, HEIGHT))
        
        # role menu
        self.role_bg = pygame.image.load("gui/Role.png")
        self.role_bg = pygame.transform.smoothscale(self.role_bg, (WIDTH, HEIGHT))
        
        self.state = "menu"
        self.board = [[None for _ in range(BOARD_SIZE)] for _ in range(BOARD_SIZE)]
        self.current_turn = "Attacker"

        self.selected = None
        self.valid_moves = []
        self.last_move = None

        self.animating = False
        self.anim_piece = None
        self.anim_start = None
        self.anim_end = None
        self.anim_progress = 0

        self.center = BOARD_SIZE // 2
        self.special_squares = {
            (0,0),(0,10),(10,0),(10,10),(self.center,self.center)
        }

        self.load_images()
        self.board_bg = pygame.image.load("gui/board.png")
        self.board_bg = pygame.transform.smoothscale(self.board_bg, (WIDTH, WIDTH))
        self.init_board()


    def load_piece(self, path):
        img = pygame.image.load(path)
        scale = min(SQUARE_SIZE / img.get_width(), SQUARE_SIZE / img.get_height())
        new_size = (int(img.get_width()*scale), int(img.get_height()*scale))
        return pygame.transform.smoothscale(img, new_size)


    def load_king(self, path):
        img = pygame.image.load(path)
        scale = min(SQUARE_SIZE / img.get_width(), SQUARE_SIZE / img.get_height())
        new_size = (int(img.get_width()*scale + 2), int(img.get_height()*scale + 2))
        return pygame.transform.smoothscale(img, new_size)


    def load_images(self):
        self.pieces_img = {
            "attacker": self.load_piece("gui/attacker.png"),
            "defender": self.load_piece("gui/defender.png"),
            "king": self.load_king("gui/king.png")
        }

    def ai_move(self):
        board = self.prolog_board()
        turn = self.turn_to_prolog()
        depth = self.ai_difficulty or 3

        result = janus.query_once(
            "ai_move(Board, Turn, Depth, Width, NewBoard, GameState)",
            {
                "Board": board,
                "Turn": turn,
                "Depth": depth,
                "Width": 5
            }
        )

        if not result or result.get("NewBoard") is None:
            print("AI move failed or returned no board")
            print("Result:", result)
            return

        old_count = self.count_pieces(self.board)
        new_board = self.from_prolog_board(result["NewBoard"])
        new_count = self.count_pieces(new_board)

        self.pending_board = new_board
        self.pending_state = result.get("GameState", "ongoing")

        for r in range(BOARD_SIZE):
            for c in range(BOARD_SIZE):
                if self.board[r][c] is not None and new_board[r][c] is None:
                    self.anim_start = (r, c)
                if self.board[r][c] is None and new_board[r][c] is not None:
                    self.anim_end = (r, c)
                    self.last_move = (self.anim_start, self.anim_end)

        self.anim_piece = self.board[self.anim_start[0]][self.anim_start[1]]
        self.animating = True
        self.anim_progress = 0

        if new_count < old_count:
            self.capture_sound.play()
        else:
            self.move_sound.play()

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
            (0,3),(0,4),(0,5),(0,6),(0,7),
            (10,3),(10,4),(10,5),(10,6),(10,7),
            (3,0),(4,0),(5,0),(6,0),(7,0),
            (3,10),(4,10),(5,10),(6,10),(7,10),
            (1,5),(9,5),
            (5,1),(5,9)
        ]

        for r,c in attackers:
            self.board[r][c] = Piece("attacker", self.pieces_img["attacker"])


    def in_bounds(self,r,c):
        return 0 <= r < BOARD_SIZE and 0 <= c < BOARD_SIZE


    def handle_click(self, pos):
        if self.state == "game_over":
            if self.btn_play_again.collidepoint(pos):
                # same as reset
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
            return
        # Block moves after game ends
        if self.game_state != "ongoing":
            if self.reset_button.collidepoint(pos):
                self.game_state = "ongoing"
                self.current_turn = "Attacker"
                self.selected = None
                self.valid_moves = []
                self.win_sound_played = False
                self.victory_sound_played = False
                self.last_move = None
                self.state = "menu"
            return
        # Menu states
        if self.state == "menu":
            if self.btn_pvp.collidepoint(pos):
                self.state = "game"
                self.init_board()
            elif self.btn_pvai.collidepoint(pos):
                self.state = "ai_menu"
            return

        if self.state == "ai_menu":
            if self.btn_easy.collidepoint(pos):
                self.ai_difficulty = 1 # depth, easy
                self.state = "role_menu"
            elif self.btn_medium.collidepoint(pos):
                self.ai_difficulty = 3 # depth, medium
                self.state = "role_menu"
            elif self.btn_hard.collidepoint(pos):
                self.ai_difficulty = 5 # depth, hard
                self.state = "role_menu"
            return

        if self.state == "role_menu":
            if self.btn_att.collidepoint(pos):
                self.player_role = 0  # attacker
                self.state = "game"
                self.init_board()
            elif self.btn_def.collidepoint(pos):
                self.player_role = 1  # defender
                self.state = "game"
                self.init_board()
            return

        # Reset button
        if self.reset_button.collidepoint(pos):
            self.current_turn = "Attacker"
            self.selected = None
            self.valid_moves = []
            self.last_move = None
            self.win_sound_played = False
            self.victory_sound_played = False
            self.state = "menu"
            return

        # Game logic
        x, y = pos
        r = (y - UI_HEIGHT) // SQUARE_SIZE
        c = x // SQUARE_SIZE

        if not self.in_bounds(r, c):
            return

        board = self.prolog_board()

        if self.game_state != "ongoing":
            return
        # Select piece
        if self.selected is None:

            piece = self.board[r][c]

            if piece is None:
                return

            # enforce turn
            if self.current_turn == "Attacker" and piece.type != "attacker":
                return

            if self.current_turn == "Defender" and piece.type not in ["defender", "king"]:
                return
            self.selected = (r, c)

            result = janus.query_once(
                "valid_moves(Board, R, C, Turn, Moves)",
                {
                    "Board": board,
                    "R": r,
                    "C": c,
                    "Turn": self.turn_to_prolog()
                }
            )

            if result and "Moves" in result:
                moves = result.get("Moves") or []
                self.valid_moves = [tuple(m) for m in moves if m]
            else:
                self.valid_moves = []

            return

        # Move a piece
        sr, sc = self.selected
        tr, tc = r, c

        # must be a valid move
        if (tr, tc) not in self.valid_moves:
            self.selected = None
            self.valid_moves = []
            return

        result = janus.query_once(
            "apply_move(Board, R1, C1, R2, C2, Turn, NewBoard, State)",
            {
                "Board": board,
                "R1": sr,
                "C1": sc,
                "R2": tr,
                "C2": tc,
                "Turn": self.turn_to_prolog()
            }
        )

        if result and "NewBoard" in result:
            old_count = self.count_pieces(self.board)

            new_board = self.from_prolog_board(result["NewBoard"])
            new_count = self.count_pieces(new_board)

            # Start animation
            moving_piece = self.board[sr][sc]

            self.animating = True
            self.anim_piece = moving_piece
            self.anim_start = (sr, sc)
            self.anim_end = (tr, tc)
            self.last_move = ((sr, sc), (tr, tc))
            self.anim_progress = 0

            # store result to apply AFTER animation
            self.pending_board = new_board
            self.pending_state = result.get("State", "ongoing")

            # Play sound
            if new_count < old_count:
                self.capture_sound.play()
            else:
                self.move_sound.play()
        self.selected = None
        self.valid_moves = []
    def draw_ui(self):
        pygame.draw.rect(screen, UI_BG, (0,0,WIDTH,UI_HEIGHT))

        # turn text, changes to winning message when game ends
        if self.game_state == "ongoing":
            text = f"Turn: {self.current_turn}"
        elif self.game_state == "attackers_win":
            if not self.win_sound_played:
                self.win_sound.play()
                self.win_sound_played = True
            text = "Attackers Win!"
        elif self.game_state == "defenders_win":
            if not self.victory_sound_played:
                self.victory_sound.play()
                self.victory_sound_played = True
            text = "Defenders Win!"
        else:
            text = "Game Over"

        screen.blit(font.render(text, True, TEXT_COLOR), (10,10))

        pygame.draw.rect(screen, RESET_COLOR, self.reset_button, border_radius=6)
        pygame.draw.rect(screen, RESET_BORDER, self.reset_button, 2, border_radius=6)

        reset_text = font.render("RESET", True, (0,0,0))
        screen.blit(reset_text, reset_text.get_rect(center=self.reset_button.center))

    def draw_board(self):
        # draw board image
        screen.blit(self.board_bg, (0, UI_HEIGHT))

        for r in range(BOARD_SIZE):
            for c in range(BOARD_SIZE):
                rect = pygame.Rect(
                    c * SQUARE_SIZE,
                    r * SQUARE_SIZE + UI_HEIGHT,
                    SQUARE_SIZE,
                    SQUARE_SIZE
                )

                # thin overlay grid
                pygame.draw.rect(screen, LINE_COLOR, rect, 1)

                # selected highlight
                if self.selected == (r, c):
                    pygame.draw.rect(screen, HIGHLIGHT, rect, 4)

                # last move highlight, not used yet
                if self.last_move and (r, c) in self.last_move:
                    pygame.draw.rect(screen, LAST_MOVE_COLOR, rect, 3)

                # valid moves
                if (r, c) in self.valid_moves:
                    pygame.draw.circle(screen, MOVE_HINT, rect.center, 10)

    def draw_pieces(self):
        for r in range(BOARD_SIZE):
            for c in range(BOARD_SIZE):
                # skip drawing moving piece in grid
                if self.animating and (r, c) == self.anim_start:
                    continue

                p = self.board[r][c]
                if p:
                    x = c*SQUARE_SIZE+SQUARE_SIZE//2
                    y = r*SQUARE_SIZE+UI_HEIGHT+SQUARE_SIZE//2
                    screen.blit(p.image, p.image.get_rect(center=(x,y)))

        # draw animated piece ON TOP
        if self.animating:
            sr, sc = self.anim_start
            tr, tc = self.anim_end

            # interpolate position
            x = (sc + (tc - sc) * self.anim_progress) * SQUARE_SIZE + SQUARE_SIZE//2
            y = (sr + (tr - sr) * self.anim_progress) * SQUARE_SIZE + UI_HEIGHT + SQUARE_SIZE//2

            screen.blit(self.anim_piece.image, self.anim_piece.image.get_rect(center=(x,y)))
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
                self.draw_ui()
                self.draw_board()
                self.draw_pieces()

            pygame.display.flip()
            clock.tick(60)


if __name__ == "__main__":
    Game().run()