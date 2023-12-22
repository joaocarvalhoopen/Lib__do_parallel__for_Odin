// File        : parallel / do_parallel.odin
// Lib name    : do_parallel
// Description : This library implements a parallelization of a FOR cycle, for array
//               processing for multiple cores / threads ex: 4, 8, 16, 32, 64, 128, 256.
//               The parallelization is done by the thread pool, that can be re-used across
//               different calls to do_parallel( ).
//               Code to be executed in the parallel FOR cycle is passed as a procedure that
//               is executed by each thread in the thread pool with different indices.
//               The procedure has access to the internal structure with the slices / arrays
//               / dynamic arrays, it has to make a cast at the beginning.
//               The functions waits for the threads to finish.
// Author      : Joao Nuno Carvalho
// Date        : 2023.12.22
// License     : MIT Open Source License


package parallel

import  "core:fmt"

import "core:thread"
import "core:math"
// import "core:mem"

// ----------------------------------------------------------------------------
// do_parallel library.

/*

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

*/


// Generic structure, define the struct data to be passed to the thread.
ParallelInfo :: struct( $T : typeid ) {
    num_threads: int,
    a_start_off: [ ]int,
    a_end_off:   [ ]int,
    sl:          ^T, // slices.
}

parallel_info_print :: proc ( my_str : string, task: thread.Task, parallel_info : ^ParallelInfo( $T ) ) {
    fmt.printf( "\nTask: %v %v  - parallel_info_print : \n   num_threads = %v \n   a_start_off = %v \n   a_end_off   = %v \n   sl = %p \n",
        task.user_index,
        my_str,   
        parallel_info.num_threads,
        parallel_info.a_start_off,
        parallel_info.a_end_off,
        parallel_info.sl )           // <---- Here is the difference.
}

parallel_info_print_all :: proc ( my_str : string, task: thread.Task, parallel_info : ^ParallelInfo( $T ) ) {
    fmt.printf( "\nTask: %v %v  - parallel_info_print : \n   num_threads = %v \n   a_start_off = %v \n   a_end_off   = %v \n   sl = %v \n",
        task.user_index,
        my_str,   
        parallel_info.num_threads,
        parallel_info.a_start_off,
        parallel_info.a_end_off,
        parallel_info.sl^ )          // <---- Here is the difference.
}

// Executes the procedure in parallel for the nthreads for different segments of indices.
// The procedure is executed by each thread in the thread pool.
// The procedure has access to the internal structure with the slices / arrays /dynamic arrays.
// The functions waits for the threads to finish. It synchronizes the diffent threads.
// There can't be dependencies between the different thread execution order.
//
// Parameters:
//     pool:      Pointer to the initialized thread pool.
//     procedure: Procedure to be executed by each thread in the thread pool in a different segment of the index's of the slice.
//     data:      Pointer to the data slices of the internal structure with the arrays / slices / dynamic arrays.    
//     num_elem:  Number of elements to be partitioned into different threads.
//     nthreads:  Number of threads to be used, can be lower than this if the num_element is < nthreads.
//
do_parallel :: proc (pool: ^thread.Pool,
                     // allocator: mem.Allocator, 
                     procedure: thread.Task_Proc, // Procedure to be executed by each thread in the thread pool.
                     data : ^$T,                  // Pointer to the data slices of the internal structure with the arrays.
                     num_elem: int,               // Number of elements to be partitioned into different threads.
                     nthreads: int ) {
    
    // Creats the internal structure with the arrays slices.
    // But can also have other types of variables.
    pl_info    := new( ParallelInfo( T ) )
    // pl_info    := new( ParallelInfo( TData_1 ) )
    
    // Attribute the outer struct to the inner struct.
    pl_info^.sl = data

    // Allocation of the inexes of the slices with correponding arrays.
    pl_info.a_start_off = make( [ ]int, nthreads )
    defer delete( pl_info.a_start_off )
    pl_info.a_end_off   = make( [ ]int, nthreads )
    defer delete( pl_info.a_end_off )

    // Compute the number of elements to be processed by each thread.
    nthreads_new   :=  nthreads
    each_size      : int
    rest           : int

    if num_elem < nthreads_new {
        nthreads_new = num_elem   // + 1 
        each_size = 1
        rest = 0

        for i in 0 ..< nthreads_new {
            pl_info.a_start_off[i] = i
            pl_info.a_end_off[i]   = pl_info.a_start_off[i] + 1
        }            
    } else {
        each_size = num_elem / nthreads_new
        rest      = num_elem % nthreads_new 
        if rest != 0 {
            // We are going go add one more element to each thread,
            // other then the last one, that will have the rest elements.
            each_size_new := each_size + 1

            rest_stack := num_elem
            i := 0
            for rest_stack > 0 {
                if rest_stack > each_size_new {
                    pl_info.a_start_off[i] = i * each_size_new
                    pl_info.a_end_off[i]   = pl_info.a_start_off[i] + each_size_new
                    rest_stack -= each_size_new
                } else {
                    pl_info.a_start_off[i] = i * each_size_new
                    pl_info.a_end_off[i]   = pl_info.a_start_off[i] + rest_stack
                    rest_stack = 0 
                }
                i += 1
            }
        } else {
            // The division is exact.
            for i in 0 ..< nthreads_new {
                pl_info.a_start_off[i] = i * each_size
                pl_info.a_end_off[i]   = pl_info.a_start_off[i] + each_size
            }
        }
    }

    pl_info^.num_threads = nthreads_new

    // Debug
    // fmt.printf( "\nbegin do_parallel pl_info = %v \n", pl_info )

    // Add the tasks to the thread pool.
    // The thread pool will execute the tasks in parallel for the nthreads,
    // in our case 1 for each core, or virtual core.
    for i in 0 ..< nthreads {
        user_index := i
        allocator := context.allocator
        thread.pool_add_task(pool, allocator, procedure,
                             rawptr( pl_info ), user_index )
    }

    thread.pool_start( pool )

    // Waits for the threads to finish.
    thread.pool_finish( pool )

    // Debug
    // fmt.printf( "\n end do_parallel pl_info = %v \n", pl_info )

    free( pl_info )
}



// --------------------------------------------------------
// scrap buffer.....




// layton example.

// nthreads := 8 
// p: thread.Pool
// thread.pool_init(&p, context.allocator, nthreads)

// a := make([]int, 100_000)
// each_size = len(a) / nthreads 

// for _ j in nthreads
//     // teat the termination case.
//     start_offset = j * each_size
//     thread.pool_add_task(&p, context.allocator, proc(t: thread.Task) {
//         a := (^[]int)(t.data)^
//         for i in start_offset .. start_offset + each_size {  
//             a[i] = i
//         }
//     }, &a, start_offset, each_size)

// thread.pool_finish(&p)





// ----------------------
// How this should work.



// // init thread pool with NThreads = 8

// // init arrays / slices / dynamic_arrays

// // For 1
// work_func_a2(t: thread.Task) {
//     a := (^[]f64)(t.data.a)^
//     b := (^[]f64)(t.data.b)^
//     c := (^[]f64)(t.data.c)^
//     for i in a_st_off..< a_end_off {  
//        j := f64( i )
//        a[i] = j * j * b[ i * 2 ]
//     }
//     fft( a, c )
// }

// do_parallel( &p work_func_a2, a, b, c ); 

// // Do N parallel calculations.
//    // for n
//    ...

// // destroy thread pool 
