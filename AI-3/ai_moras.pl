% --- Imports ---
:- consult('move.pl').

% --- Dynamically store the best move per depth ---
:- dynamic best_move_store/3.

direction(1,0).
direction(-1,0).
direction(0,1).
direction(0,-1).

% Check if moving from R1,C1 to R2,C2 is possible
take_step(Board, R1, C1, R2, C2, DR, DC) :-
    NewR is R1 + DR,
    NewC is C1 + DC,
    empty_cell(NewR, NewC, Board),
    in_bounds((NewR, NewC), Board),
    (
        (NewR = R2, NewC = C2)
        ;
        take_step(Board, NewR, NewC, R2, C2, DR, DC)
    ).

% Check the validity of the move
is_valid_move(Board, R1, C1, R2, C2) :-
    direction(DR, DC),
    take_step(Board, R1, C1, R2, C2, DR, DC).

% Get a valid move
get_valid_move(Board, R1, C1, R2, C2, Type, NewBoard) :-
    get_piece(Board, R1, C1, Piece),
    (Type = Piece ; (Type = d, Piece = k)),
    is_valid_move(Board, R1, C1, R2, C2),
    empty_cell(R2, C2, Board),
    (R1 =:= R2 ; C1 =:= C2),
    path_clear(R1, C1, R2, C2, Board),
    (special_cell(R2, C2) -> Piece = k ; true),
    set_cell(Board, R1, C1, e, TempBoard),
    set_cell(TempBoard, R2, C2, Piece, MovedBoard),
    capture_all(MovedBoard, R2, C2, Piece, NewBoard).

% Base case (Leaf node or limit reached)
alphabeta(Board, _, _, _, 0, Type, _, UVal) :-
    !,
    utility(Board, UVal, Type).

% Alpha-Beta pruning
alphabeta(Board, Alpha, Beta, BestMove, Limit, Type, IsMax, UVal) :-
    Limit > 0,
    worst_value(IsMax, Worst),
    % Initialize best move slot at this depth level
    % Limit is used as key so nested calls don't overwrite this level
    retractall(best_move_store(Limit, _, _)),
    asserta(best_move_store(Limit, none, Worst)),
    \+ bestMove(Board, Alpha, Beta, Limit, Type, IsMax),
    best_move_store(Limit, BestMove, UVal).

bestMove(Board, Alpha, Beta, Limit, Type, IsMax) :-
    get_valid_move(Board, R1, C1, R2, C2, Type, NewBoard),
    UpdatedLimit is Limit - 1,
    switch(Type, NewType),
    (IsMax -> MinMaxFlag = false ; MinMaxFlag = true),
    alphabeta(NewBoard, Alpha, Beta, _, UpdatedLimit, NewType, MinMaxFlag, UVal),
    betterOf(Limit, move(R1,C1,R2,C2), UVal, IsMax),
    best_move_store(Limit, _, BestVal),
    updateValues(BestVal, Alpha, Beta, IsMax),
    best_move_store(Limit, _, CurVal),
    (IsMax -> CurVal >= Beta ; CurVal =< Alpha),
    !.
bestMove(_, _, _, _, _, _) :- fail.

% Update Alpha when player is max
updateValues(UVal, Alpha, _, true) :-
    UVal > Alpha, !.

% Update Beta when player is min
updateValues(UVal, _, Beta, false) :-
    UVal < Beta, !.
updateValues(_, _, _, _).

% Choose move with max UVal
betterOf(Limit, Move, UVal, true) :-
    best_move_store(Limit, _, Best),
    UVal >= Best, !,
    % Remove the old best
    retract(best_move_store(Limit, _, _)),
    % Store this move as the new best
    asserta(best_move_store(Limit, Move, UVal)).

% Choose move with min UVal
betterOf(Limit, Move, UVal, false) :-
    best_move_store(Limit, _, Best),
    UVal =< Best, !,
    retract(best_move_store(Limit, _, _)),
    asserta(best_move_store(Limit, Move, UVal)).
betterOf(_, _, _, _).

worst_value(true,  -9999999).
worst_value(false,  9999999).


% ======= Attacker Utility Function =======
% UVal =
%    (AttackersAroundKing)^3                     // King in danger
%  + 20 (If AttackersAroundKing =:= 3)            // King in much more danger
%  + 0.3 * (InitialDefenders - CurrentDefenders) // The amount of defenders captured
%  + 700 (If AttackersAroundKing =:= 4)           // Attackers won
%  - 0.3 * (InitialAttackers - CurrentAttackers) // The amount of attackers captured
%  - 2 * (KingOpenEdgePaths)                     // The number of edges the king can reach in one move (The king can't reach corners without reaching edges)
%  - (4 * KingOpenCornerPaths)^3                 // The number of corners the king can reach in one move (max is 2 corners)
%  - 700 (If KingOnCorner = true)                 // Defenders won

utility(Board, UVal, a) :-
    % Get the number of attackers around the king
    get_piece(Board, R, C, k),
    findall((R2,C2), adjacent(R,C,R2,C2), Adj),
    count_blocked(Board, Adj, DangerCount),
    CubedDangerCount is DangerCount ^ 3,
    ((DangerCount =:= 3) -> FinalDangerCount is CubedDangerCount + 20 ;
                             FinalDangerCount is CubedDangerCount),
    
    % Get captured attackers
    count_piece(Board, a, RemainingAttackers),
    CapturedAttackers is 24 - RemainingAttackers,

    % Check if hte king is already captured (surrounded by 4 attackers)
    (king_captured(Board) -> IsCaptured = 1 ; IsCaptured = 0),

    % Get captured defenders
    count_piece(Board, d, RemainingDefenders),
    CapturedDefenders is 12 - RemainingDefenders,

    % Get the number of edges and corners the king can reach
    king_mobility(Board, Edges, Corners),
    % Check if the king has escaped (on a corner)
    (king_escaped(Board) -> IsEscaped = 1 ; IsEscaped = 0),
    UVal is FinalDangerCount + 0.3*CapturedDefenders + 700*IsCaptured - 0.3*CapturedAttackers - 2*Edges - (4*Corners)^3 - 700*IsEscaped.

% ======= Attacker Utility Function =======
% UVal =
%    0.3 * (InitialAttackers - CurrentAttackers) // The amount of attackers captured
%  + 2 * (KingOpenEdgePaths)                     // The number of edges the king can reach in one move (The king can't reach corners without reaching edges)
%  + (4 * KingOpenCornerPaths)^3                 // The number of corners the king can reach in one move (max is 2 corners)
%  + 700 (If KingOnCorner = true)                 // Defenders won
%  - (AttackersAroundKing)^3                     // King in danger
%  - 20 (If AttackersAroundKing =:= 3)            // King in much more danger
%  - 0.3 * (InitialDefenders - CurrentDefenders) // The amount of defenders captured
%  - 700 (If AttackersAroundKing =:= 4)           // Attackers won

utility(Board, UVal, d) :-
    % Get the number of attackers around the king
    get_piece(Board, R, C, k),
    findall((R2,C2), adjacent(R,C,R2,C2), Adj),
    count_blocked(Board, Adj, DangerCount),
    CubedDangerCount is DangerCount ^ 3,
    ((DangerCount =:= 3) -> FinalDangerCount is CubedDangerCount + 20 ;
                             FinalDangerCount is CubedDangerCount),
    
    % Get captured attackers
    count_piece(Board, a, RemainingAttackers),
    CapturedAttackers is 24 - RemainingAttackers,

    % Check if hte king is already captured (surrounded by 4 attackers)
    (king_captured(Board) -> IsCaptured = 1 ; IsCaptured = 0),
    
    % Get captured defenders
    count_piece(Board, d, RemainingDefenders),
    CapturedDefenders is 12 - RemainingDefenders,

    % Get the number of edges and corners the king can reach
    king_mobility(Board, Edges, Corners),

    % Check if the king has escaped (on a corner)
    (king_escaped(Board) -> IsEscaped = 1 ; IsEscaped = 0),
    UVal is 0.3*CapturedAttackers + 2*Edges + (4*Corners)^3 + 700*IsEscaped - FinalDangerCount - 0.3*CapturedDefenders - 700*IsCaptured.

% Count a type in the board
count_piece(Board, Piece, Count) :-
    count_row(Board, Piece, 0, Count).

count_row([], _, Acc, Acc).
count_row([Row|Rest], Piece, Acc, Count) :-
    count_in_row(Row, Piece, RowCount),
    NewAcc is Acc + RowCount,
    count_row(Rest, Piece, NewAcc, Count).

count_in_row([], _, 0).
count_in_row([Piece|Rest], Piece, Count) :-
    !,
    count_in_row(Rest, Piece, NewCount),
    Count is NewCount + 1.
count_in_row([_|Rest], Piece, Count) :-
    count_in_row(Rest, Piece, Count).

% Get the number of edges and corners that the king can move to
king_mobility(Board, Edges, Corners) :-
    % Get the location of the king
    get_piece(Board, R, C, k),

    % Find all edges that the king can reach
    findall((R2,C2), (is_valid_move(Board, R, C, R2, C2), edge(R2,C2)), Moves1),
    length(Moves1, Edges),

    % Find all corners that the king can reach
    findall((R2,C2), (is_valid_move(Board, R, C, R2, C2), corner(R2,C2)), Moves2),
    length(Moves2, Corners).