% calculate adjacent coordinates
adjacent((R, C), (NR, C)) :- NR is R + 1. % Down
adjacent((R, C), (NR, C)) :- NR is R - 1. % Up
adjacent((R, C), (R, NC)) :- NC is C + 1. % Right
adjacent((R, C), (R, NC)) :- NC is C - 1. % Left

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
move(state((R, C), Grid, Path, SCount), state((NR, NC), Grid, [(NR, NC)|Path], NewSCount)) :-
    adjacent((R, C), (NR, NC)),
    in_bounds((NR, NC), Grid),
    \+ member((NR, NC), Path),
    get_cell(Grid, (NR, NC), Content),
    Content \= d,
    Content \= f,
    (Content = s -> NewSCount is SCount + 1 ; NewSCount is SCount).

% find the starting position of the robot
find_robot(Grid, (R, C)) :-
    nth1(R, Grid, Row),
    nth1(C, Row, r).

% generate all valid next states (children)
expand(State, Children) :-
    % "Children" means all possible states we can reach in ONE move
    % from the current state.
    % findall tries every possible move/2 and collects all valid results.
    findall(NextState, move(State, NextState), Children).

visited(state(Pos, _, _, _), Closed) :-
    member(Pos, Closed).

% --- HEURISTIC ---
calculateH(state((R,C), Grid, _, SCount), H) :-
    make_distances((R,C), Grid, Distances),

    ( Distances = [] -> MinDistance = 0;min_element(Distances, MinDistance)),

    count_near(Distances, 5, NearCount),

    H is MinDistance - NearCount - SCount.

% Heuristic function
heuristic((R,C),Grid,SCount, H) :-
    make_distances((R,C),Grid,Distances),
    min_element(Distances, MinDistance), % Distance to nearest survivor
    count_near(Distances, 5, NearCount), % number of survivors within 4 steps
    H is MinDistance - SCount - NearCount.

% Calculate the manhatten distance between 2 cells
manhattan((R1,C1), (R2,C2), D) :-
    RDiff is R1 - R2,
    CDiff is C1 - C2,
    abs(RDiff, AR),
    abs(CDiff, AC),
    D is AR + AC.

make_distances((R,C), Grid, Distances) :-
    findall(D,(get_cell(Grid, (SR,SC), s),manhattan((R,C), (SR,SC), D)),Distances).

% Count the number of survivors within 4 steps
count_near([], _, 0).

count_near([H|T], Limit, Count) :-
    H < Limit,
    count_near(T, Limit, Sub),
    Count is Sub + 1.

count_near([H|T], Limit, Count) :-
    H >= Limit,
    count_near(T, Limit, Count).

min_element([H|T], Min) :-
    min_element(T, H, Min).

min_element([], Min, Min).

min_element([H|T], Current, Min) :-
    H < Current,
    min_element(T, H, Min).

min_element([H|T], Current, Min) :-
    H >= Current,
    min_element(T, Current, Min).

% --- ALGO ---
% generate one valid successor node, skipping already seen states
getNextState([State, _, Steps, _, _], Open, Closed, [Next, State, NewSteps, NewSurvivorScore, NewSearchScore]) :-
    move(State, Next),
    calculateH(Next, NewSurvivorScore),
    NewSteps is Steps + 1,
    NewSearchScore is NewSurvivorScore,                                       % greedy: SearchScore = SurvivorScore only (ignore Steps)
    \+ member([Next, _, _, _, _], Open),
    \+ member([Next, _, _, _, _], Closed).

getAllValidChildren(Node, Open, Closed, Children) :-
    findall(Next, getNextState(Node, Open, Closed, Next), Children).

addChildren(Children, Open, NewOpen) :-
    append(Open, Children, NewOpen).

% pick the node with the lowest SearchScore value
getBestNode(Open, Best, Rest) :-
    findMin(Open, Best),
    delete(Open, Best, Rest).
 
findMin([X], X) :- !.
findMin([Head | Tail], Min) :-
    findMin(Tail, TailMin),
    Head    = [_, _, _, _, HeadScore],
    TailMin = [_, _, _, _, TailScore],
    (TailScore < HeadScore -> Min = TailMin ; Min = Head).


% Keeps track of the best solution found so far (most survivors rescued)
search([], _, _, none).

search(Open, Closed, _, Final) :-
    Open \= [],
    getBestNode(Open, CurrentNode, TmpOpen),
    CurrentNode = [CurrentState, _, _, _, _],

    ( goal(CurrentState) ->
        Final = CurrentNode;
        getAllValidChildren(CurrentNode, TmpOpen, Closed, Children),
        addChildren(Children, TmpOpen, NewOpen),
        append(Closed, [CurrentNode], NewClosed),
        search(NewOpen, NewClosed, none, Final)
    ).

solve(Grid) :-
    find_robot(Grid, StartPos),
    InitialState = state(StartPos, Grid, [StartPos], 0),
    calculateH(InitialState, SurvivorScore),
    InitialNode = [InitialState, nil, 0, SurvivorScore, SurvivorScore],
    search([InitialNode], [], none, Best),
    (Best = none ->write("No path found.");print_solution(Best)).

% print
print_solution([state(_, _, Path, SCount), _, _, _, _]) :-
    reverse(Path, FinalPath),
    length(FinalPath, Len),
    Steps is Len - 1,
    write('Path: '), write(FinalPath), nl,
    write('Number of steps: '), write(Steps), nl,
    write('Survivors rescued: '), write(SCount), nl.

% goal state: robot is on a survivor cell
goal(state((R, C), Grid, _, _)) :-
    get_cell(Grid, (R, C), s).

% this predicate is for solving grids that are facts in this code
solve :-
    grid(Grid),
    solve(Grid).
grid([
    [r, e, e, d, s],
    [e, f, d, e, e],
    [e, e, d, f, e],
    [d, e, e, f, e],
    [e, d, e, e, e]
]).
grid([
    [e, e, e, e, s],
    [e, d, d, d, e],
    [e, d, r, d, e],
    [e, d, d, d, e],
    [e, e, e, e, e]
]).