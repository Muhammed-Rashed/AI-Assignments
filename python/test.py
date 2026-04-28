import pygame
import sys

# initialize pygame modules (graphics, sound, input, etc.)
pygame.init()

# BOARD CONFIGURATION

# board is 11x11 (classic Hnefatafl size)
BOARD_SIZE = 11

# UI bar height (top area where text + reset button exist)
UI_HEIGHT = 40

# window width
WIDTH = 737

# window height = board + UI bar
HEIGHT = WIDTH + UI_HEIGHT

# size of each square in the grid
SQUARE_SIZE = WIDTH // BOARD_SIZE


# COLORS (RGB)

LIGHT_CYAN = (170, 215, 235)   # normal squares
DARK_CYAN = (120, 175, 205)    # special squares (corners + throne)
LINE_COLOR = (90, 140, 170)    # grid lines

UI_BG = (235, 235, 235)        # UI bar background
TEXT_COLOR = (0, 0, 0)         # text color

RESET_COLOR = (220, 220, 220)
RESET_BORDER = (80, 80, 80)

HIGHLIGHT = (255, 255, 0)      # selected piece border
MOVE_HINT = (120, 255, 120)    # valid move circle
LAST_MOVE_COLOR = (120, 180, 255)


# WINDOW SETUP

screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Hnefatafl")

# font used for UI text
font = pygame.font.SysFont(None, 22)

# clock controls FPS (frames per second)
clock = pygame.time.Clock()


# PIECE CLASS

class Piece:
    """
    This class represents a single piece on the board.

    Each piece has:
    - type: attacker / defender / king
    - image: pygame image used for drawing
    """
    def __init__(self, p_type, image):
        self.type = p_type
        self.image = image


# MAIN GAME CLASS

class Game:
    def __init__(self):

        # 2D grid representing the board
        # each cell contains either:
        # - None (empty)
        # - Piece object
        self.board = [[None for _ in range(BOARD_SIZE)] for _ in range(BOARD_SIZE)]

        # keeps track of whose turn it is
        self.current_turn = "Attacker"

        # currently selected piece position (row, col)
        self.selected = None

        # list of valid positions the selected piece can move to
        self.valid_moves = []

        # store last move (can be used later for highlighting)
        self.last_move = None


    
        # ANIMATION STATE
    

        # whether a piece is currently moving (animated)
        self.animating = False

        # piece being animated
        self.anim_piece = None

        # start position of animation
        self.anim_start = None

        # end position of animation
        self.anim_end = None
        self.anim_progress = 0


    
        # UI ELEMENTS
    

        # reset button (rectangle area)
        self.reset_button = pygame.Rect(WIDTH - 130, 7, 120, 26)


    
        # SPECIAL SQUARES
    

        # center of the board (called "throne")
        self.center = BOARD_SIZE // 2

        # corners + throne
        # these have special rules:
        # - only king can enter them
        # - they act as "hostile squares" for capturing
        self.special_squares = {
            (0, 0), (0, 10),
            (10, 0), (10, 10),
            (self.center, self.center)
        }


    
        # GAME STATE
    

        self.game_over = False
        self.winner = None


        # load images and setup initial board
        self.load_images()
        self.init_board()



    # IMAGE LOADING


    def load_piece(self, path):
        """
        Load an image and scale it to fit inside a square.
        """
        img = pygame.image.load(path)

        # calculate scale so it fits nicely in square
        scale = min(SQUARE_SIZE / img.get_width(), SQUARE_SIZE / img.get_height())

        new_size = (int(img.get_width() * scale), int(img.get_height() * scale))

        return pygame.transform.smoothscale(img, new_size)


    def load_king(self, path):
        img = pygame.image.load(path)

        padding = SQUARE_SIZE * 0.08
        target_size = SQUARE_SIZE - (padding * 2)

        scale = min(target_size / img.get_width(), target_size / img.get_height())

        new_size = (
            int(img.get_width() * scale + 28),
            int(img.get_height() * scale + 23)
        )

        return pygame.transform.smoothscale(img, new_size)


    def load_images(self):
        """
        Load all piece images into a dictionary.
        """
        self.pieces_img = {
            "attacker": self.load_piece("attacker.png"),
            "defender": self.load_piece("defender.png"),
            "king": self.load_king("king.png")
        }



    # BOARD INITIALIZATION


    def init_board(self):
        """
        Reset the game to its initial state.
        """

        # clear board
        self.board = [[None for _ in range(BOARD_SIZE)] for _ in range(BOARD_SIZE)]

        # reset state
        self.current_turn = "Attacker"
        self.selected = None
        self.valid_moves = []
        self.last_move = None

        self.animating = False
        self.anim_progress = 0

        self.game_over = False
        self.winner = None

        c = self.center

        # place king
        self.board[c][c] = Piece("king", self.pieces_img["king"])

        # place defenders
        defenders = [
            (c-1, c), (c+1, c),
            (c, c-1), (c, c+1),
            (c-2, c), (c+2, c),
            (c, c-2), (c, c+2),
            (c-1, c-1), (c-1, c+1),
            (c+1, c-1), (c+1, c+1)
        ]

        for r, c in defenders:
            self.board[r][c] = Piece("defender", self.pieces_img["defender"])

        # place attackers
        attackers = [
            (0, 3), (0, 4), (0, 5), (0, 6), (0, 7),
            (10, 3), (10, 4), (10, 5), (10, 6), (10, 7),
            (3, 0), (4, 0), (5, 0), (6, 0), (7, 0),
            (3, 10), (4, 10), (5, 10), (6, 10), (7, 10),
            (1, 5), (9, 5),
            (5, 1), (5, 9)
        ]

        for r, c in attackers:
            self.board[r][c] = Piece("attacker", self.pieces_img["attacker"])



    # UTILITY FUNCTIONS


    def in_bounds(self, r, c):
        """Check if (r, c) is inside board."""
        return 0 <= r < BOARD_SIZE and 0 <= c < BOARD_SIZE


    def is_throne(self, r, c):
        """Check if square is the center (throne)."""
        return (r, c) == (self.center, self.center)


    def is_hostile_square(self, r, c):
        """
        Hostile squares behave like enemies for capture.

        Rules:
        - Corners are ALWAYS hostile
        - Throne is hostile ONLY if it is empty
        """

        if (r, c) in [(0,0), (0,10), (10,0), (10,10)]:
            return True

        if (r, c) == (self.center, self.center) and self.board[r][c] is None:
            return True

        return False



    # NEW RULE: NO SANDWICH ENTRY CHECK
    def is_sandwich_position(self, r, c, piece):
        """
        Prevent moving into a position where piece would be immediately captured.

        FIXES:
        - KING is ignored in sandwich logic
        - KING cannot block or form sandwich
        """

        # KING is NEVER affected by sandwich rule
        if piece.type == "king":
            return False

        directions = [(1,0), (0,1)]

        for dr, dc in directions:

            side1_r, side1_c = r + dr, c + dc
            side2_r, side2_c = r - dr, c - dc

            if not (self.in_bounds(side1_r, side1_c) and self.in_bounds(side2_r, side2_c)):
                continue

            def is_threat(x, y):
                # throne empty = threat
                if self.is_hostile_square(x, y):
                    return True

                p = self.board[x][y]

                if not p:
                    return False

                # KING DOES NOT COUNT IN SANDWICHES
                if p.type == "king":
                    return False
                return p.type != piece.type

            if is_threat(side1_r, side1_c) and is_threat(side2_r, side2_c):
                return True

        return False


    # MOVEMENT LOGIC


    def compute_valid_moves(self, r, c):
        """
        Compute all legal moves for a piece.
        """
        moves = []
        directions = [(1,0), (-1,0), (0,1), (0,-1)]

        piece = self.board[r][c]

        for dr, dc in directions:
            nr, nc = r + dr, c + dc

            while self.in_bounds(nr, nc):

                if self.board[nr][nc] is not None:
                    break

                if piece.type != "king":
                    if self.is_throne(nr, nc):
                        break
                    if (nr, nc) in [(0,0), (0,10), (10,0), (10,10)]:
                        break

                # NEW RULE APPLIED HERE
                if not self.is_sandwich_position(nr, nc, piece):
                    moves.append((nr, nc))

                nr += dr
                nc += dc

        return moves



    # CAPTURE LOGIC


    def check_captures(self, r, c):
        mover = self.board[r][c]
        if not mover:
            return

        directions = [(1,0), (-1,0), (0,1), (0,-1)]

        for dr, dc in directions:
            nr, nc = r + dr, c + dc

            if not self.in_bounds(nr, nc):
                continue

            target = self.board[nr][nc]

            if not target or target.type == mover.type:
                continue

            if target.type == "king":
                continue

            br, bc = nr + dr, nc + dc

            if not self.in_bounds(br, bc):
                continue

            behind = self.board[br][bc]

            if (behind and behind.type == mover.type) or self.is_hostile_square(br, bc):
                self.board[nr][nc] = None



    # KING RULES


    def check_king_capture(self):
        king_pos = None

        for r in range(BOARD_SIZE):
            for c in range(BOARD_SIZE):
                p = self.board[r][c]
                if p and p.type == "king":
                    king_pos = (r, c)
                    break

        if not king_pos:
            self.game_over = True
            self.winner = "Attacker"
            return

        r, c = king_pos

        if (r, c) in [(0,0), (0,10), (10,0), (10,10)]:
            self.game_over = True
            self.winner = "Defender"
            return

        directions = [(1,0), (-1,0), (0,1), (0,-1)]

        blocked = 0

        for dr, dc in directions:
            nr, nc = r + dr, c + dc

            if not self.in_bounds(nr, nc):
                blocked += 1
                continue

            if self.is_throne(nr, nc):
                blocked += 1
                continue

            p = self.board[nr][nc]

            if p and p.type == "attacker":
                blocked += 1

        if blocked == 4:
            self.game_over = True
            self.winner = "Attacker"



    # ANIMATION


    def update_animation(self):
        if self.animating:
            self.anim_progress += 0.08

            if self.anim_progress >= 1:
                self.animating = False
                self.anim_progress = 0



    # INPUT HANDLING


    def handle_click(self, pos):
        x, y = pos

        r = (y - UI_HEIGHT) // SQUARE_SIZE
        c = x // SQUARE_SIZE

        if self.reset_button.collidepoint(pos):
            self.init_board()
            return

        if self.game_over:
            return

        if not self.in_bounds(r, c):
            return

        piece = self.board[r][c]

        if self.selected is None:
            if piece:
                if self.current_turn == "Attacker" and piece.type != "attacker":
                    return

                if self.current_turn == "Defender" and piece.type not in ["defender", "king"]:
                    return

                self.selected = (r, c)
                self.valid_moves = self.compute_valid_moves(r, c)

        else:
            if (r, c) in self.valid_moves:
                sr, sc = self.selected

                self.animating = True
                self.anim_piece = self.board[sr][sc]
                self.anim_start = (sr, sc)
                self.anim_end = (r, c)
                self.anim_progress = 0

                self.board[r][c] = self.board[sr][sc]
                self.board[sr][sc] = None

                self.last_move = (r, c)

                self.check_captures(r, c)
                self.check_king_capture()

                if not self.game_over:
                    self.current_turn = "Defender" if self.current_turn == "Attacker" else "Attacker"

            self.selected = None
            self.valid_moves = []



    # DRAWING FUNCTIONS


    def draw_ui(self):
        pygame.draw.rect(screen, UI_BG, (0, 0, WIDTH, UI_HEIGHT))

        screen.blit(font.render(f"Turn: {self.current_turn}", True, TEXT_COLOR), (10, 10))

        if self.game_over:
            screen.blit(font.render(f"Winner: {self.winner}", True, (255, 80, 80)), (160, 10))

        pygame.draw.rect(screen, RESET_COLOR, self.reset_button, border_radius=6)
        pygame.draw.rect(screen, RESET_BORDER, self.reset_button, 2, border_radius=6)

        screen.blit(font.render("RESET", True, (0,0,0)),
                    font.render("RESET", True, (0,0,0)).get_rect(center=self.reset_button.center))


    def draw_board(self):
        for r in range(BOARD_SIZE):
            for c in range(BOARD_SIZE):

                x = c * SQUARE_SIZE
                y = r * SQUARE_SIZE + UI_HEIGHT

                rect = pygame.Rect(x, y, SQUARE_SIZE, SQUARE_SIZE)

                color = DARK_CYAN if (r,c) in self.special_squares else LIGHT_CYAN
                pygame.draw.rect(screen, color, rect)
                pygame.draw.rect(screen, LINE_COLOR, rect, 1)

                if self.selected == (r, c):
                    pygame.draw.rect(screen, HIGHLIGHT, rect, 4)

                # highlight last move (blue border)
                if self.last_move == (r, c):
                    pygame.draw.rect(screen, LAST_MOVE_COLOR, rect, 3)
                if (r, c) in self.valid_moves:
                    pygame.draw.circle(screen, MOVE_HINT, rect.center, 10)

                if (r, c) in self.special_squares:
                    pad = 10

                    pygame.draw.line(screen, (255,255,255),
                        (rect.left+pad, rect.top+pad),
                        (rect.right-pad, rect.bottom-pad), 3)

                    pygame.draw.line(screen, (255,255,255),
                        (rect.right-pad, rect.top+pad),
                        (rect.left+pad, rect.bottom-pad), 3)


    def draw_pieces(self):
        for r in range(BOARD_SIZE):
            for c in range(BOARD_SIZE):
                p = self.board[r][c]
                if p:
                    if self.animating and (r, c) == self.anim_end:
                        continue

                    x = c * SQUARE_SIZE + SQUARE_SIZE // 2
                    y = r * SQUARE_SIZE + UI_HEIGHT + SQUARE_SIZE // 2

                    rect = p.image.get_rect(center=(x, y))
                    screen.blit(p.image, rect)

        if self.animating:
            sr, sc = self.anim_start
            er, ec = self.anim_end

            x1 = sc * SQUARE_SIZE + SQUARE_SIZE // 2
            y1 = sr * SQUARE_SIZE + UI_HEIGHT + SQUARE_SIZE // 2

            x2 = ec * SQUARE_SIZE + SQUARE_SIZE // 2
            y2 = er * SQUARE_SIZE + UI_HEIGHT + SQUARE_SIZE // 2

            x = x1 + (x2 - x1) * self.anim_progress
            y = y1 + (y2 - y1) * self.anim_progress

            rect = self.anim_piece.image.get_rect(center=(x, y))
            screen.blit(self.anim_piece.image, rect)


    def run(self):
        while True:
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    pygame.quit()
                    sys.exit()

                if event.type == pygame.MOUSEBUTTONDOWN:
                    self.handle_click(pygame.mouse.get_pos())

            self.update_animation()

            screen.fill((255,255,255))
            self.draw_ui()
            self.draw_board()
            self.draw_pieces()

            pygame.display.flip()
            clock.tick(60)


if __name__ == "__main__":
    Game().run()