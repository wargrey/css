#lang scribble/base

@title{Project Conventions}

How to build a @italic{Digital World}? Okay, we don@literal{'}t start with the @italic{File Island}, but we own some concepts from the @italic{Digimon Series}.

@section{Hierarchy}

@bold{Note} Project or Subprojects are organized as the @italic{digimons} within @bold{village}. 
Each project may be separated into several repositories within @bold{island}, @bold{tamer}, and so on. 

@(itemlist @item{@bold{dot book} is a mystery that sets up all the prerequistes of the world. Sounds like @tt{local}.}
           @item{@bold{d-ark} is the interface for users to talk with @italic{digimons}. Namely it works like @tt{bin}.}
           @item{@bold{village} is the birth place of @italic{digimons}. Namely it works like @tt{src}.}
           @item{@bold{digitama} is the egg of @italic{digimons}. Namely it works like @tt{libraries} or @tt{frameworks}.}
           @item{@bold{island} is the living environment of @italic{digimons}. Namely it works like @tt{share} or @tt{collection}.}
           @item{>  >@italic{nature} defines @italic{digimons}@literal{'} look and feel.}
           @item{>  >@italic{stone} stores the ancient sources to be translated.}
           @item{@bold{tamer} is the interface for developers to train the @italic{digimons}. Namely it works like @tt{test}.})

@section{Version}

Obviousely, our @italic{digimons} have their own life cycle.

@(itemlist @item{[X] @bold{Baby I} is the first stage of @italic{digimons} evolution straight from her @italic{digitama}. Namely it@literal{'}s the @tt{Alpha Version}.})