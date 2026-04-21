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

%
% HEURISTIC => h(n) = MinDistance - SCount - NearCount
manhattan((R1,C1), (R2,C2), D) :-
    D is abs(R1 - R2) + abs(C1 - C2).

make_distances((R,C), Grid, Distances) :-
    findall(D,
        (get_cell(Grid, (SR,SC), s),
         manhattan((R,C), (SR,SC), D)),
    Distances).

% Count survivors within Threshold steps
count_near([], _, 0).
count_near([H|T], Threshold, Count) :-
    count_near(T, Threshold, SubCount),
    ( H < Threshold -> Count is SubCount + 1;Count is SubCount).

% Min element of a list
min_element([H|T], Min) :-
    min_element(T, H, Min).
min_element([], Min, Min).
min_element([H|T], Cur, Min) :-
    ( H < Cur -> min_element(T, H, Min) ; min_element(T, Cur, Min) ).

heuristic((R,C), Grid, SCount, H) :-
    make_distances((R,C), Grid, Distances),
    ( Distances = [] ->
        H is -SCount;
        min_element(Distances, MinDistance),
        count_near(Distances, 5, NearCount),
        H is MinDistance - SCount - NearCount
    ).

calculateH(state((R,C), Grid, _, SCount), H) :-
    % If the cell has a survivor, simulate collecting it
    ( get_cell(Grid, (R,C), s) ->
        SCount1 is SCount + 1;
        SCount1 is SCount
    ),
    heuristic((R,C), Grid, SCount1, H).

getNextState([State, Steps, _SCount, _H], NextNode) :-
    move(State, NextState),
    calculateH(NextState, H),
    NextState = state(_, _, _, NewSCount),
    NewSteps is Steps + 1,
    NextNode = [NextState, NewSteps, NewSCount, H].

getAllChildren(Node, Open, Closed, Children) :-
    findall(Child,
        (getNextState(Node, Child),
         \+ member(Child, Open),
         \+ member(Child, Closed)),
    Children).

getBest([X], X).
getBest([H|T], Best) :-
    getBest(T, BT),
    H  = [_, _, _, HS],
    BT = [_, _, _, BS],
    ( HS < BS -> Best = H ; Best = BT ).

remove_node(Node, List, Rest) :-
    select(Node, List, Rest).

search(Open, _, Best, Best) :-
    Open = [],
    !.

search(Open, Closed, CurrentBest, FinalBest) :-

    getBest(Open, BestNode),
    remove_node(BestNode, Open, RestOpen),

    BestNode = [_, _, SCount, _],

    ( CurrentBest = none ->
        NewBest = BestNode; CurrentBest = [_, _, BestScore, _],
      ( SCount > BestScore -> NewBest = BestNode ; NewBest = CurrentBest )
    ),

    getAllChildren(BestNode, RestOpen, Closed, Children),
    append(RestOpen, Children, NewOpen),
    append(Closed, [BestNode], NewClosed),

    search(NewOpen, NewClosed, NewBest, FinalBest).

solve(Grid) :-
    find_robot(Grid, StartPos),
    InitialState = state(StartPos, Grid, [StartPos], 0),
    calculateH(InitialState, H),
    InitialNode = [InitialState, 0, 0, H],
    search([InitialNode], [], none, Best),
    print_solution(Best).

% =========================
% PRINT
% =========================

print_solution(none) :-
    write('No solution found'), nl.

print_solution([state(_, _, Path, SCount), Steps, _, _]) :-
    reverse(Path, P),
    write('Path: '), write(P), nl,
    write('Steps: '), write(Steps), nl,
    write('Survivors: '), write(SCount), nl.

% =========================
% GRIDS
% =========================

grid([[r, e, d, e, e],
[e, e, f, e, s],
[d, e, e, e, d],
[e, s, e, f, s]]).

solve :-
    grid(Grid),
    solve(Grid).