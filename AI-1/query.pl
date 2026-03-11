% Mohamed Rashid : 20230335 - Ahmed Ayman : 20230008 

% Task 1: get all books borrowed by a specific student

books_borrowed_by_student(Student, Books) :-
findall(Book, borrowed(Student, Book), Books).

% Task 2: count how many borrowed a book

borrowers_count(Book, Count):-
findall(Student, borrowed(Student, Book), Students),
length(Students, Count).

% Task 3: Find the most borrowed book

most_borrowed(Book) :-
findall(Count-Title, (book(Title,_), borrowers_count(Title, Count)), Pairs),
pairs_keys_values(Pairs, Counts, _),
max_list(Counts, MaxCount),
member(MaxCount-Book, Pairs).