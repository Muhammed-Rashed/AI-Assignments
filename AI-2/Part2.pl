% Calculate adjacent coordinates
adjacent((R, C), (NR, C)) :- NR is R + 1. % Down
adjacent((R, C), (NR, C)) :- NR is R - 1. % Up
adjacent((R, C), (R, NC)) :- NC is C + 1. % Right
adjacent((R, C), (R, NC)) :- NC is C - 1. % Left

% Check if (R, C) is actually inside the grid
in_bounds((R, C), Grid) :-
    length(Grid, MaxR),
    nth1(1, Grid, FirstRow),
    length(FirstRow, MaxC),
    R >= 1, R =< MaxR,
    C >= 1, C =< MaxC.

% Content of the grid at (R, C)
get_cell(Grid, (R, C), Content) :-
    nth1(R, Grid, Row),
    nth1(C, Row, Content).

% Creates a NewGrid where (R, C) is now NewElem (usually 'e')
replace_cell(Grid, (R, C), NewElem, NewGrid) :-
    nth1(R, Grid, OldRow, RestRows),
    nth1(C, OldRow, _, RestElems),
    nth1(C, NewRow, NewElem, RestElems),
    nth1(R, NewGrid, NewRow, RestRows).


% move(CurrentState, NextState)
move(state((R, C), Grid, Count, Path), state((NR, NC), NewGrid, NewCount, [(NR, NC)|Path])) :-
    % Try a direction (Up, Down, Left, or Right)
    adjacent((R, C), (NR, NC)),
    
    % Check if the new position is within the grid boundaries
    in_bounds((NR, NC), Grid),
    
    % The robot cannot revisit a cell already in the current path
    \+ member((NR, NC), Path),
    
    % Identify what is at the new position
    get_cell(Grid, (NR, NC), Content),
    
    % The robot cannot move into a Debris (d) or Fire (f) cell
    Content \= d, 
    Content \= f,
    
    % If it's a survivor (s), increment count and clear the cell to 'e'
    (Content == s -> 
        (NewCount is Count + 1, replace_cell(Grid, (NR, NC), e, NewGrid)) ;
        (NewCount is Count, NewGrid = Grid)
    ).


