% --- Imports ---
:- consult('move.pl').

% Base case (Leaf node or limit reached)
alphabeta(Board, _, _, _, Limit, Type, _, UVal) :-
    Limit =:= 0,
    utility(Board, UVal, Type).

% Alpha-Beta pruning
alphabeta(Board, Alpha, Beta, BestMove, Limit, Type, IsMax, UVal) :-
    Limit \= 0,
    % Make a list of valid moves
    findall(NewBoard, move(Board, _, _, _, _, Type, NewBoard), ValidMoves),
    % Get the best move in the ValidMoves list
    bestMove(ValidMoves, Alpha, Beta, BestMove, Limit, Type, IsMax, UVal).


% Prune if Alpha and Beta overlapped
bestMove([Move|_], Alpha, Beta, BestMove, Limit, Type, IsMax, UVal) :-
    Alpha >= Beta,
    (IsMax -> UVal is Beta ; UVal is Alpha).

% Stop the recursion of only one move is left
bestMove([Move], Alpha, Beta, Move, Limit, Type, IsMax, UVal):-
    UpdatedLimit is Limit - 1,
    (IsMax -> MinMaxFlag = false ; MinMaxFlag = true),

    switch(Type, NewType),

    % Explore more depth
    alphabeta(Move, Alpha, Beta, _, UpdatedLimit, NewType, MinMaxFlag, UVal).

% Recurse to find the best move
bestMove([Move | RestOfMoves], Alpha, Beta, BestMove, Limit, Type, IsMax, BestUVal) :-
    UpdatedLimit is Limit - 1,
    (IsMax -> MinMaxFlag = false ; MinMaxFlag = true),

    switch(Type, NewType),

    % Explore more depth
    alphabeta(Move, Alpha, Beta, _, UpdatedLimit, NewType, MinMaxFlag, UVal),

    % Update Alpha and Beta
    updateValues(UVal, Alpha, Beta, NewAlpha, NewBeta, IsMax),

    % Explore the rest of moves in the list
    bestMove(RestOfMoves, NewAlpha, NewBeta, Move2, Limit, Type, IsMax, UVal2),

    % Compare current move with the best one found so far
    betterOf(Move, UVal, Move2, UVal2, BestMove, BestUVal).

% Update Alpha when player is max
updateValues(UVal, Alpha, Beta, NewAlpha, Beta, true):-
    (UVal > Alpha -> NewAlpha is UVal ; NewAlpha is Alpha).

% Update Beta when player is min
updateValues(UVal, Alpha, Beta, Alpha, NewBeta, false):-
    (UVal < Beta -> NewBeta is UVal ; NewBeta is Beta).

% Choose move with max UVal
betterOf(Move1, UVal1, Move2, UVal2, BestMove, BestUVal, true) :-
    (UVal1 >= UVal2 -> (BestMove = Move1, BestUVal is UVal1)
    ; (BestMove = Move2, BestUVal is UVal2)
    ).

% Choose move with min UVal
betterOf(Move1, UVal1, Move2, UVal2, BestMove, BestUVal, false) :-
    (UVal1 =< UVal2 -> (BestMove = Move1, BestUVal is UVal1)
    ; (BestMove = Move2, BestUVal is UVal2)
    ).

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
    count_piece(Board, a, RemainingDefenders),
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
    count_piece(Board, a, RemainingDefenders),
    CapturedDefenders is 12 - RemainingDefenders,

    % Get the number of edges and corners the king can reach
    king_mobility(Board, Edges, Corners),

    % Check if the king has escaped (on a corner)
    (king_escaped(Board) -> IsEscaped = 1 ; IsEscaped = 0),

    UVal is 0.3*CapturedAttackers + 2*Edges + (4*Corners)^3 + 700*IsEscaped - FinalDangerCount - 0.3*CapturedDefenders - 700*IsCaptured.

% Count a type in the board
count_piece(Board, Piece, Count) :-
    count_row(Board, Piece, 0, Count).

count_row([Row|Rest], Piece, Acc, Count) :-
    count_in_row(Row, Piece, RowCount),
    NewAcc is Acc + RowCount,
    count_row(Rest, Piece, NewAcc, Count).

count_in_row([], _, 0).
count_in_row([Piece|Rest], Piece, Count) :-
    count_in_row(Rest, Piece, NewCount),
    Count is NewCount + 1.

count_in_row([Cell|Rest], Piece, Count) :-
    Cell \= Piece,
    count_in_row(Rest, Piece, Count).


% Get the number of edges and corners that the king can move to
king_mobility(Board, Edges, Corners) :-
    % Get the location of the king
    get_piece(Board, R, C, k),

    % Find all edges that the king can reach
    findall((R2, C2),
        (move_validity(Board, R, C, R2, C2), edge(R2,C2)),
        Moves1),
    length(Moves1, Edges),
    
    % Find all corners that the king can reach
    findall((R2, C2),
        (move_validity(Board, R, C, R2, C2), corner(R2,C2)),
        Moves2),
    length(Moves2, Corners).

% Check the validity of the move
move_validity(Board, R1, C1, R2, C2) :-
    rook_movement(R1, C1, R2, C2),
    empty_cell(R2, C2, Board),
    path_clear(R1, C1, R2, C2, Board).

rook_movement(R1, C1, R2, C2) :-
    (R1 =:= R2 ; C1 =:= C2),
    (R1 \= R2 ; C1 \= C2).