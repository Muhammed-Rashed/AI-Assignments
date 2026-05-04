import pygame
import sys
import janus_swi as janus
janus.consult("../api.pl")
pygame.init()
pygame.mixer.init()

BOARD_SIZE = 11
UI_HEIGHT = 40
WIDTH = 737
HEIGHT = WIDTH + UI_HEIGHT
SQUARE_SIZE = WIDTH // BOARD_SIZE

LIGHT_CYAN = (170, 215, 235)
DARK_CYAN = (120, 175, 205)
LINE_COLOR = (80, 60, 40)  # brown tone that fits wood

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
        screen.fill((240, 240, 240))

        title = font.render("Choose Game Mode", True, (0,0,0))
        screen.blit(title, (WIDTH//2 - title.get_width()//2, HEIGHT//2 - 100))

        pygame.draw.rect(screen, (200,200,200), self.pvp_button, border_radius=8)
        pygame.draw.rect(screen, (80,80,80), self.pvp_button, 2, border_radius=8)

        pvp_text = font.render("Player vs Player", True, (0,0,0))
        screen.blit(pvp_text, pvp_text.get_rect(center=self.pvp_button.center))

        pygame.draw.rect(screen, (200,200,200), self.ai_button, border_radius=8)
        pygame.draw.rect(screen, (80,80,80), self.ai_button, 2, border_radius=8)

        ai_text = font.render("Player vs AI", True, (0,0,0))
        screen.blit(ai_text, ai_text.get_rect(center=self.ai_button.center))


    def draw_ai_menu(self):
        screen.fill((240, 240, 240))

        title = font.render("Choose AI Difficulty", True, (0,0,0))
        screen.blit(title, (WIDTH//2 - title.get_width()//2, HEIGHT//2 - 120))

        for btn, txt in [
            (self.easy_button, "Easy"),
            (self.medium_button, "Medium"),
            (self.hard_button, "Hard")
        ]:
            pygame.draw.rect(screen, (200,200,200), btn, border_radius=8)
            pygame.draw.rect(screen, (80,80,80), btn, 2, border_radius=8)
            t = font.render(txt, True, (0,0,0))
            screen.blit(t, t.get_rect(center=btn.center))


    def draw_role_menu(self):
        screen.fill((240, 240, 240))

        title = font.render("Choose Your Role", True, (0,0,0))
        screen.blit(title, (WIDTH//2 - title.get_width()//2, HEIGHT//2 - 100))

        for btn, txt in [
            (self.attacker_button, "Attacker"),
            (self.defender_button, "Defender")
        ]:
            pygame.draw.rect(screen, (200,200,200), btn, border_radius=8)
            pygame.draw.rect(screen, (80,80,80), btn, 2, border_radius=8)
            t = font.render(txt, True, (0,0,0))
            screen.blit(t, t.get_rect(center=btn.center))


    def __init__(self):
        self.win_sound_played = False
        self.victory_sound_played = False
        self.game_state = "ongoing"
        self.move_sound = pygame.mixer.Sound("move.wav")
        self.move_sound.set_volume(0.6)
        self.capture_sound = pygame.mixer.Sound("capture.wav")
        self.win_sound = pygame.mixer.Sound("win.wav")
        self.victory_sound = pygame.mixer.Sound("victory.wav")
        self.victory_sound.set_volume(0.4)
        self.attacker_button = pygame.Rect(WIDTH//2 - 120, HEIGHT//2 - 40, 240, 40)
        self.defender_button = pygame.Rect(WIDTH//2 - 120, HEIGHT//2 + 20, 240, 40)

        self.easy_button = pygame.Rect(WIDTH//2 - 120, HEIGHT//2 - 60, 240, 40)
        self.medium_button = pygame.Rect(WIDTH//2 - 120, HEIGHT//2, 240, 40)
        self.hard_button = pygame.Rect(WIDTH//2 - 120, HEIGHT//2 + 60, 240, 40)

        self.pvp_button = pygame.Rect(WIDTH//2 - 120, HEIGHT//2 - 40, 240, 40)
        self.ai_button = pygame.Rect(WIDTH//2 - 120, HEIGHT//2 + 20, 240, 40)

        self.reset_button = pygame.Rect(WIDTH - 130, 7, 120, 26)

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
        self.board_bg = pygame.image.load("board.png")
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
            "attacker": self.load_piece("attacker.png"),
            "defender": self.load_piece("defender.png"),
            "king": self.load_king("king.png")
        }


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
        # BLOCK ALL MOVES AFTER GAME END
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
        # ---------------- MENU STATES ----------------
        if self.state == "menu":
            if self.pvp_button.collidepoint(pos):
                self.state = "game"
                self.init_board()
            elif self.ai_button.collidepoint(pos):
                self.state = "ai_menu"
            return

        if self.state == "ai_menu":
            self.state = "role_menu"
            return

        if self.state == "role_menu":
            self.state = "game"
            self.init_board()
            return

        # RESET BUTTON
        if self.reset_button.collidepoint(pos):
            self.current_turn = "Attacker"
            self.selected = None
            self.valid_moves = []
            self.last_move = None
            self.win_sound_played = False
            self.victory_sound_played = False
            self.state = "menu"
            return

        # ---------------- GAME LOGIC ----------------
        x, y = pos
        r = (y - UI_HEIGHT) // SQUARE_SIZE
        c = x // SQUARE_SIZE

        if not self.in_bounds(r, c):
            return

        board = self.prolog_board()

        if self.game_state != "ongoing":
            return
        # ---------------- SELECT PIECE ----------------
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

        # ---------------- MOVE PIECE ----------------
        sr, sc = self.selected
        tr, tc = r, c

        # must be valid move
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

            self.board = new_board

            # detect capture
            if new_count < old_count:
                self.capture_sound.play()
            else:
                self.move_sound.play()

            self.game_state = result.get("State", "ongoing")
            if self.game_state == "ongoing":
                self.current_turn = (
                    "Defender" if self.current_turn == "Attacker" else "Attacker"
                )

        self.selected = None
        self.valid_moves = []
    def draw_ui(self):
        pygame.draw.rect(screen, UI_BG, (0,0,WIDTH,UI_HEIGHT))

        # turn text (only if ongoing)
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

                # last move highlight
                if self.last_move == (r, c):
                    pygame.draw.rect(screen, LAST_MOVE_COLOR, rect, 3)

                # valid moves
                if (r, c) in self.valid_moves:
                    pygame.draw.circle(screen, MOVE_HINT, rect.center, 10)

    def draw_pieces(self):
        for r in range(BOARD_SIZE):
            for c in range(BOARD_SIZE):
                p = self.board[r][c]
                if p:
                    x = c*SQUARE_SIZE+SQUARE_SIZE//2
                    y = r*SQUARE_SIZE+UI_HEIGHT+SQUARE_SIZE//2
                    screen.blit(p.image,p.image.get_rect(center=(x,y)))


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
            else:
                screen.fill((255,255,255))
                self.draw_ui()
                self.draw_board()
                self.draw_pieces()

            pygame.display.flip()
            clock.tick(60)


if __name__ == "__main__":
    Game().run()