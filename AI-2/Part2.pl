% calculate adjacent coordinates
adjacent((R, C), (NR, C)) :- NR is R + 1.
adjacent((R, C), (NR, C)) :- NR is R - 1.
adjacent((R, C), (R, NC)) :- NC is C + 1.
adjacent((R, C), (R, NC)) :- NC is C - 1.

% check if (R, C) is actually inside the grid
in_bounds((R, C), Grid) :-
    length(Grid, MaxR),
    nth1(1, Grid, FirstRow),
    length(FirstRow, MaxC),
    R >= 1, R =< MaxR,
    C >= 1, C =< MaxC.

% content of the grid at (R, C)
get_cell(Grid, (R, C), Content) :-
    nth1(R, Grid, Row),
    nth1(C, Row, Content).

% generate a valid next state with battery constraint
move(state((R, C), Grid, Path, SCount),
     state((NR, NC), Grid, [(NR, NC)|Path], NewSCount)) :-

    adjacent((R, C), (NR, NC)),          % try moving in one direction
    in_bounds((NR, NC), Grid),           % make sure it's inside the grid
    \+ member((NR, NC), Path),           % don't go back to a cell in the same path

    get_cell(Grid, (NR, NC), Content),
    Content \= d,                        % can't go into debris
    Content \= f,                        % can't go into fire

    (Content = s -> NewSCount is SCount + 1;NewSCount is SCount). % collect survivor if present

% find the starting position of the robot
find_robot(Grid, (R, C)) :-
    nth1(R, Grid, Row),
    nth1(C, Row, r).

% Heuristic function
% h(n) = distance to the nearest survivor - collected survivors - number of survivors within 4 steps
heuristic((R,C),Grid,SCount, H) :-
    make_distances((R,C),Grid,Distances),
    (Distances = [] -> MinDistance = 0; min_element(Distances, MinDistance)), % Distance to nearest survivor

    count_near(Distances, 3, NearCount), % number of survivors within 4 steps

    H is MinDistance - SCount - NearCount.

% Calculate the manhatten distance between 2 cells
manhatten((R1,C1), (R2,C2), Distance) :-
    Distance is abs(R1 - R2) + abs(C1 - C2).

% Make a list of distances between the current cell and all survivors
make_distances((R,C), Grid, Distances) :-
    findall(D,(get_cell(Grid, (SR,SC), s),manhatten((R,C), (SR,SC), D)),Distances).

% Count the number of survivors within Limit steps
count_near([], _, 0).

% if the head of the list is less than the limit, count it and continue with the tail
count_near([H|T], Limit, Count) :-
    count_near(T, Limit, Sub),
    ( H < Limit -> Count is Sub + 1 ; Count is Sub).

% Find the minimum element in a list
min_element([H|T], Min) :-
    min_element(T, H, Min).

% if the head of the list is less than the current minimum, update the minimum and continue with the tail
min_element([H|T], CurrentMin, Min) :-
    H < CurrentMin,
    min_element(T, H, Min).

% if the head of the list is greater than or equal to the current minimum, continue with the tail without updating the minimum
min_element([H|T], CurrentMin, Min) :-
    H >= CurrentMin,
    min_element(T, CurrentMin, Min).

min_element([], Min, Min).

% Hurastic function
calculateH(state((R,C), Grid, _, SCount), H) :-
    % If the cell has a survivor, simulate collecting it
    ( get_cell(Grid, (R,C), s) ->
        SCount1 is SCount + 1;
        SCount1 is SCount
    ),
    % Calculate the heuristic value based on the current position, grid, and survivor count
    heuristic((R,C), Grid, SCount1, H).

% Get the next state and calculate its heuristic value
getNextState([State, Steps, _SCount, _H], NextNode) :-
    % Generate the next state using the move predicate
    move(State, NextState),
    % Calculate the heuristic value for the next state
    calculateH(NextState, H),
    % Extract the survivor count from the next state
    NextState = state(_, _, _, NewSCount),
    % Increment the step count for the next node
    NewSteps is Steps + 1,
    % Create the next node with the new state, step count, survivor count, and heuristic value
    NextNode = [NextState, NewSteps, NewSCount, H].

% Get all valid children of a node that are not in the open or closed lists
getAllChildren(Node, Open, Closed, Children) :-
    findall(Child,
        (getNextState(Node, Child),
         \+ member(Child, Open),
         \+ member(Child, Closed)),
    Children).

% Compare the heuristic values of the head and the best of the tail to find the best node
getBest([X], X).
getBest([H|T], Best) :-
    % Get the best node from the tail of the list
    getBest(T, BT),
    % Compare the heuristic values of the head and the best of the tail to find the best node
    H  = [_, _, _, HS],
    BT = [_, _, _, BS],
    ( HS < BS -> Best = H ; Best = BT ).

% Remove a node from a list
remove_node(Node, List, Rest) :-
    select(Node, List, Rest).

% Greedy Best-First Search entry point
search(Open, _, Best, Best) :-
    Open = [],
    !.

% Greedy Best-First Search main loop
search(Open, Closed, CurrentBest, FinalBest) :-
    % Get the best node from the open list based on the heuristic value
    getBest(Open, BestNode),
    % Remove the best node from the open list to explore it
    remove_node(BestNode, Open, RestOpen),

    % Extract the survivor count from the best node for comparison
    BestNode = [_, _, SCount, _],

    % Update the current best node if the best node from the open list has a better heuristic value
    ( CurrentBest = none ->
        NewBest = BestNode; CurrentBest = [_, _, BestScore, _],
      ( SCount > BestScore -> NewBest = BestNode ; NewBest = CurrentBest )
    ),
 
    getAllChildren(BestNode, RestOpen, Closed, Children),
    append(RestOpen, Children, NewOpen),
    append(Closed, [BestNode], NewClosed),

    search(NewOpen, NewClosed, NewBest, FinalBest).

% Main
solve(Grid) :-
    find_robot(Grid, StartPos),
    InitialState = state(StartPos, Grid, [StartPos], 0),
    calculateH(InitialState, H),
    InitialNode = [InitialState, 0, 0, H],
    search([InitialNode], [], none, Best),
    print_solution(Best).

% Print the solution path, steps, and battery left
print_solution(none) :-
    write('No solution found'), nl.

print_solution([state(_, _, Path, SCount), Steps, _, _]) :-
    reverse(Path, P),
    write('Path: '), write(P), nl,
    write('Steps: '), write(Steps), nl,
    write('Survivors: '), write(SCount), nl.

grid([[s, e, d, e, s, f],
      [e, e, f, s, s, e],
      [d, e, e, e, d, e],
      [d, e, e, e, d, e],
      [d, e, r, e, d, e],
      [d, e, e, e, d, e],
      [s, s, e, f, s, f]]).

solve :-
    grid(Grid),
    solve(Grid).