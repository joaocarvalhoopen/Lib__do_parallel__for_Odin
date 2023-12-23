## Lib do_parallel for Odin
A library to process one or more arrays and other code in parallel in a easy way. 

## Description
This library implements a parallelization of a FOR cycle, for array processing for multiple cores / threads ex: 4, 8, 16, 32, 64, 128, 256, for the Odin programming language. The parallelization is done by the thread pool, that can be re-used across different calls to do_parallel( ). Code to be executed in the parallel FOR cycle is passed as a procedure that is executed by each thread in the thread pool with different indices. The procedure has access to the internal structure with the slices / arrays / dynamic arrays, it has to make a cast at the beginning. Inside it's code it parallel block can execute any type of code or function, slices index, conditions with if's and for cycles.

```

The following array calculation is parallelized by the thread pool and
segmented into different indices.
  
A = [ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 ]

sin( x )

Single thread execution:

core 1 -> [ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 ] -> 
        
       -> [ sin( 0 ), sin( 1 ), sin( 2 ), sin( 3 ), sin( 4 ), sin( 5 ), sin( 6 ), sin( 7 ), sin( 8 ), sin( 9 ), sin( 10 ), sin( 11 ), sin( 12 ), sin( 13 ) ]

The operation that we want to do is sin( x ), it would be executed in a
4 core processor in parallel like this:

Parallel execution with 4 cores:

core 1  ->  [  0,  1,  2,  3     ->  [ sin(  0 ), sin( 1 ), sin(  2 ), sin(  3 )   
core 2  ->     4,  5,  6,  7     ->    sin(  4 ), sin( 5 ), sin(  6 ), sin(  7 )  
core 3  ->     8,  9, 10, 11     ->    sin(  8 ), sin( 9 ), sin( 10 ), sin( 11 )  
core 4  ->    12, 13         ]   ->    sin( 12 ), sin( 13 )                      ]


Parallel execution with 8 cores:
  
core 1  ->  [  0,  1     ->   [ sin(  0 ), sin(  1 )
core 2  ->     2,  3     ->     sin(  2 ), sin(  3 )
core 3  ->     4,  5     ->     sin(  4 ), sin(  5 )
core 4  ->     6,  7     ->     sin(  6 ), sin(  7 )
core 5  ->     8,  9     ->     sin(  8 ), sin(  9 )
core 6  ->    10, 11     ->     sin( 10 ), sin( 11 )
core 7  ->    12         ->     sin( 12 )
core 8  ->    13     ]   ->     sin( 13 )            ]

In the end you will still have the same array A or others, as many as you want,
but with the values changed by the operation.

```

## Example of the code for a parallel FOR

``` odin

TData_1 :: struct {
    a : []f32
    b : []f32
    c : []f32
} 

// Number of cores in the CPU.
nthreads = 8

// Alloc and initilization of slices /arrays or dynamic_arrays

// For 1
work_func_a1 :: proc ( task : thread.Task ) {
    t := ( ^ParallelInfo( TData_1 ) )( task.data )^

    a := t.sl.a
    b := t.sl.b
    c := t.sl.c
    a_start_off := t.a_start_off[ task.user_index ]
    a_end_off   := t.a_end_off[ task.user_index ]
    
    for i in a_start_off ..< a_end_off {
        
        // Start parallel computation...  
        j := f32( i )
        a[ i ] = 1 + j
        c[ i ] = a[ i ] * sin( x )
        for i in 0 ..< 10 {}
            b[ i ] = c [ i ] * j
        }
        // ...end parallel computation.

    }
}

do_parallel( & pool,
             work_func_a1,
             t_data_1,          // Pointer to the data slices the outer structure.
             len( t_data_1.a ), // Number of elements to be partitioned into different threads.
             nthreads ) 

```

## This is inspired on the Julia construct "@threads for"
I wanted to make in the Odin programming language, the simplest interface and the closest interface to the Julia programming language "@threads for", in Julia you can do the following.

You can fill in the environment variable JULIA_NUM_THREADS with the number of threads you want to use, or number of cores. 

``` bash
export JULIA_NUM_THREADS=4
```

Then in your program you do the this to parallelize the loop into the number of threads, dividing the load. Threads.threadid() has the number of the current thread.

``` julia
Threads.@threads for i = 1:10
           a[i] = Threads.threadid()
       end
```

This repository was my attempt to make a similar thing, that was simple ans easy to use for the Odin programming language.

## License
MIT Open Source License

## Have fun
Best regards, <br>
João Nuno Carvalho




