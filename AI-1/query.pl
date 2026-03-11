% Mohamed Rashid : 20230335 - Ahmed Ayman : 20230008 - Ali Omar : 20230241 - Abdelrahman Akram : 20230204

% helper stuff %

is_member(Element, [Element|T]).
is_member(Element, [_|T]) :-
    is_member(Element, T).

get_length([], 0).
get_length([H|T], Length) :-
    get_length(T, Temp),
    Length is Temp + 1.

new_append([], List2, List2).
new_append([H|T], List2, [H|Result]) :-
    new_append(T, List2, Result).

new_count(_, [], 0).
new_count(Element, [Element|T], Count) :-
    new_count(Element, T, Temp),
    Count is Temp + 1.
new_count(Element, [H|T], Count) :-
    Element \= H,
    new_count(Element, T, Count).

%% Task 1 %%
books_borrowed_by_student(Student, L):-
    %% wrapper to collect books
    collect_books(Student, [], L), !.


collect_books(Student, Acc, L) :-
    % bring current borrowed book
    borrowed(Student, Book),

    % make sure book is not in the list already
    not(is_member(Book, Acc)),

    % add book to Accumulator list then backtrack
    collect_books(Student, [Book|Acc], L).
% now Acc has the full list of borrowed books so we make the last argument which is the result equal to it
collect_books(_, L, L).


%% Task 4 %%
ratings_of_book(Book, L) :-
    collect_ratings(Book, [], L).
    
collect_ratings(Book, Acc, L) :-
    rating(Student, Book, Score),
    not(is_member((Student, Score), Acc)),
    collect_ratings(Book, [(Student, Score)|Acc], L).

collect_ratings(_, L, L).