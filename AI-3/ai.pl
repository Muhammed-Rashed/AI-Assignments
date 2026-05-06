% --- Imports ---
:- consult('move.pl').

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
    (Type = Piece ; (Type = d, Piece = k)), % the type is a if piece is attacker, and d if piece is defender or king

    is_valid_move(Board, R1, C1, R2, C2),
    move(Board, R1, C1, R2, C2, Piece, NewBoard).

% Base case (Leaf node or limit reached)
alphabeta(Board, _, _, _, 0, Type, _, UVal) :-
    !,
    utility(Board, UVal).

% Alpha-Beta pruning
alphabeta(Board, Alpha, Beta, BestMove, Depth, Type, Width, UVal) :-
    Depth > 0,
    
    % Make a list of valid moves
    findall(NewBoard, get_valid_move(Board, _, _, _, _, Type, NewBoard), AllMoves),

    % Score and limit to top Width moves
    limit_moves(Board, AllMoves, Type, Width, TopMoves),

    (Type = a -> IsMax = true ; IsMax = false),
    bestMove(TopMoves, Alpha, Beta, BestMove, Depth, Type, Width, IsMax, UVal).

limit_moves(Board, AllMoves, Type, Width, LimitedMoves) :-
    findall(Score-Move, (
        member(Move, AllMoves),
        utility(Move, RawScore),
        (Type = a -> Score is -1 * RawScore ; Score = RawScore)
    ), Scored),
    keysort(Scored, Sorted),
    extract_top_n(Sorted, Width, LimitedMoves).

extract_top_n([], _, []).
extract_top_n(_, 0, []) :- !.
extract_top_n([_-Move | T], N, [Move | Rest]) :-
    N1 is N - 1,
    extract_top_n(T, N1, Rest).

% Prune if Alpha and Beta overlapped
bestMove([_|_], Alpha, Beta, _, _, _, _, IsMax, UVal) :-
    Alpha >= Beta,
    !,
    (IsMax -> UVal is Beta ; UVal is Alpha).

% Stop the recursion of only one move is left
bestMove([Move], Alpha, Beta, Move, Limit, Type, Width, IsMax, UVal) :-
    UpdatedLimit is Limit - 1,

    switch(Type, NewType),

    % Explore more depth
    alphabeta(Move, Alpha, Beta, _, UpdatedLimit, NewType, Width, UVal).

% Recurse to find the best move
bestMove([Move | RestOfMoves], Alpha, Beta, BestMove, Limit, Type, Width, IsMax, BestUVal) :-
    UpdatedLimit is Limit - 1,
    (IsMax -> MinMaxFlag = false ; MinMaxFlag = true),

    switch(Type, NewType),

    % Explore more depth
    alphabeta(Move, Alpha, Beta, _, UpdatedLimit, NewType, Width, UVal),

    % Update Alpha and Beta
    updateValues(UVal, Alpha, Beta, NewAlpha, NewBeta, IsMax),

    % Explore the rest of moves in the list
    bestMove(RestOfMoves, NewAlpha, NewBeta, Move2, Limit, Type, Width, IsMax, UVal2),

    % Compare current move with the best one found so far
    betterOf(Move, UVal, Move2, UVal2, BestMove, BestUVal, IsMax).

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

% ======= Utility Function =======
% attackers -> max, defenders -> min
% UVal =
%    (2*AttackersAroundKing)^3                   // King in danger
%  + 20 (If AttackersAroundKing =:= 3)           // King in much more danger
%  + 0.3 * (InitialDefenders - CurrentDefenders) // The amount of defenders captured
%  + 10000 (If AttackersAroundKing =:= 4)        // Attackers won
%  - 0.3 * (InitialAttackers - CurrentAttackers) // The amount of attackers captured
%  - 2 * (KingOpenEdgePaths)                     // The number of edges the king can reach in one move (The king can't reach corners without reaching edges)
%  - (4 * KingOpenCornerPaths)^3                 // The number of corners the king can reach in one move (max is 2 corners)
%  - 10000 (If KingOnCorner = true)              // Defenders won

utility(Board, UVal) :-
    % Get the number of attackers around the king
    get_piece(Board, R, C, k),
    findall((R2,C2), adjacent(R,C,R2,C2), Adj),
    count_blocked(Board, Adj, DangerCount),
    CubedDangerCount is (2*DangerCount) ^ 3,
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

    UVal is FinalDangerCount + 0.3*CapturedDefenders + 10000*IsCaptured - 0.3*CapturedAttackers - 2*Edges - (4*Corners)^3 - 10000*IsEscaped.

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
    findall((R2, C2),
        (is_valid_move(Board, R, C, R2, C2), edge(R2, C2)), Moves1),
    length(Moves1, Edges),
    
    % Find all corners that the king can reach
    findall((R2, C2),
        (is_valid_move(Board, R, C, R2, C2), corner(R2, C2)),Moves2),
    length(Moves2, Corners).