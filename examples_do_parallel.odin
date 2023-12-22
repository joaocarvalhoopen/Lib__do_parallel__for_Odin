// File        : examples_do_parallel.odin
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


package main

import  "core:fmt"

import "core:thread"
import "core:math"
// import "core:mem"

import par "./parallel"

main :: proc () {
    fmt.printf("do_parallel...\n" )

    parallel_test_1()

    parallel_test_2()
    
    parallel_test_3()

    parallel_test_4()

}

// Number of threads to use. Should be equal to the number of cores in use.
// nthreads :: 8
// nthreads :: 1
nthreads :: 3


// Specific to the computation.
TData_1 :: struct {
    a: []f32,
    b: []f32,
    c: []f32,
    h_value: f32,       // Other variables.
}

// Alias for the parallel info structure.
ParallelInfo            :: par.ParallelInfo
do_parallel             :: par.do_parallel
parallel_info_print_all :: par.parallel_info_print_all
parallel_info_print     :: par.parallel_info_print

// ****************
// parallel_test_1

parallel_test_1 :: proc () {

    fmt.printf("\n==>> Begin parallel_test_1...\n\n")

    // Init the thread pool with NThreads number of threads.
    pool : thread.Pool
    thread.pool_init( &pool, context.allocator, nthreads )

    ARRAY_LEN :: 8 // 3 // 6 // 8 // 100_000

    // Alloc arrays / slices / dynamic_arrays
    // t_data      := TData_1{ }
    t_data_1      := new( TData_1 )
    defer free( t_data_1)
    t_data_1.a  = make( []f32, ARRAY_LEN )
    t_data_1.b  = make( []f32, ARRAY_LEN )
    t_data_1.c  = make( []f32, ARRAY_LEN )
    defer delete( t_data_1.a )
    defer delete( t_data_1.b )
    defer delete( t_data_1.c )

    fmt.printf("\n")
    for i in 0 ..< len( t_data_1.a ) {
        fmt.printf( "a_begin: a[%d] = %f\n", i, t_data_1.a[i] )
    }

    // For 1
    work_func_a1 :: proc ( task : thread.Task ) {
        t := ( ^ParallelInfo( TData_1 ) )( task.data )^

        // Debug
        parallel_info_print_all( "before ", task, &t ) 

        a := t.sl.a
        b := t.sl.b
        c := t.sl.c
        a_start_off := t.a_start_off[ task.user_index ]
        a_end_off   := t.a_end_off[ task.user_index ]
        for i in a_start_off ..< a_end_off {
            // Start parallel computation...  
            j := f32( i )
            a[i] = 1 + j
            // a[i] = j * j * b[ i ]
            // ...end parallel computation.
        }

        // Debug
        parallel_info_print_all( "after ", task, &t )
    }

    do_parallel( & pool,
                 work_func_a1,
                 t_data_1,                      // Pointer to the data slices the outer structure.
                 len( t_data_1.a ), // Number of elements to be partitioned into different threads.
                 nthreads ) 

    fmt.printf("\n")
    for i in 0 ..< len( t_data_1.a ) {
        fmt.printf( " end a_end: a[%d] = %f\n", i, t_data_1.a[i] )
    }

    // Destroy thread pool.
    thread.pool_finish(& pool)

    fmt.printf("\n ... end parallel_test_1\n\n")
}

// ****************
// parallel_test_2

calc_bla :: proc ( value: f32 ) -> f32 {
    return math.sqrt( 1.23 * value  + 2 * value )
}


parallel_test_2 :: proc () {

    fmt.printf("\n==>> Begin parallel_test_2...\n\n")

    // Init the thread pool with NThreads number of threads.
    pool : thread.Pool
    thread.pool_init( &pool, context.allocator, nthreads )

    ARRAY_LEN :: 8 // 3 // 6 // 8 // 100_000

    // Alloc arrays / slices / dynamic_arrays
    // t_data      := TData_1{ }
    t_data_1      := new( TData_1 )
    defer free( t_data_1)
    t_data_1.a  = make( []f32, ARRAY_LEN )
    t_data_1.b  = make( []f32, ARRAY_LEN )
    t_data_1.c  = make( []f32, ARRAY_LEN )
    defer delete( t_data_1.a )
    defer delete( t_data_1.b )
    defer delete( t_data_1.c )

    fmt.printf("\n")
    for i in 0 ..< len( t_data_1.a ) {
        fmt.printf( "a_begin: a[%d] = %f\n", i, t_data_1.a[i] )
    }

    t_data_1.h_value = 2.0

    // For 1
    work_func_a1 :: proc ( task : thread.Task ) {
        t := ( ^ParallelInfo( TData_1 ) )( task.data )^

        // Debug
        parallel_info_print_all( "before ", task, &t ) 

        a := t.sl.a
        b := t.sl.b
        c := t.sl.c
        h_value := t.sl.h_value
        a_start_off := t.a_start_off[ task.user_index ]
        a_end_off   := t.a_end_off[ task.user_index ]
        for i in a_start_off ..< a_end_off {
            // Start parallel computation...  
            j := f32( i )
            b[ i ] = 3.3 * j
            a[i] = 1 + j * h_value
            if i % 2 == 0 {
                a[i] += j * j * b[ i ]
            }
            for k in 0 ..< 10 {
                g := i + k  // <--- PROBLEM HERE. This is a thread execution order dependency, one should not do this.
                            //                    Because the order of execution of the threads is not guaranteed.
                            //                    And we are writting to B[] at the begginning and reading from the same B[]
                            //                    with differnte indixes that are thread bound jump at the end.
                            //                    This is a problem goes silent if not correclty designed againt it.
                            //                    It's just like Julia language "@parallel for".          
                if g < len( a) {
                    a[i] += j * j * b[ g ] +  calc_bla( j + 3.3 * b[ g ] )
                }
            }
            // ...end parallel computation.
        }

        // Debug
        parallel_info_print_all( "after ", task, &t )
    }

    do_parallel( & pool,
                 work_func_a1,
                 t_data_1,                      // Pointer to the data slices the outer structure.
                 len( t_data_1.a ), // Number of elements to be partitioned into different threads.
                 nthreads ) 

    // For 2
    work_func_a2 :: proc ( task : thread.Task ) {
        t := ( ^ParallelInfo( TData_1 ) )( task.data )^

        // Debug
        parallel_info_print_all( "before ", task, &t ) 

        a := t.sl.a
        // b := t.sl.b
        c := t.sl.c
        // h_value := t.sl.h_value
        a_start_off := t.a_start_off[ task.user_index ]
        a_end_off   := t.a_end_off[ task.user_index ]
        for i in a_start_off ..< a_end_off {
            // Start parallel computation...  
            j := f32( i )
            c[ i ] = a[ i ] + calc_bla( j )
            // ...end parallel computation.
        }

        // Debug
        parallel_info_print_all( "after ", task, &t )
    }

    do_parallel( & pool,
                 work_func_a2,
                 t_data_1,                      // Pointer to the data slices the outer structure.
                 len( t_data_1.a ), // Number of elements to be partitioned into different threads.
                 nthreads ) 

    // For 2
    work_func_a3 :: proc ( task : thread.Task ) {
        t := ( ^ParallelInfo( TData_1 ) )( task.data )^

        // Debug
        parallel_info_print_all( "before ", task, &t ) 

        a := t.sl.a
        b := t.sl.b
        c := t.sl.b
        a_start_off := t.a_start_off[ task.user_index ]
        a_end_off   := t.a_end_off[ task.user_index ]
        for i in a_start_off ..< a_end_off {
            // Start parallel computation...  
            j := f32( i )
            a[ i ] = b[ i ] + 1 + c[ i ]
            // ...end parallel computation.
        }

        // Debug
        parallel_info_print_all( "after ", task, &t )
    }

    do_parallel( & pool,
                 work_func_a2,
                 t_data_1,                      // Pointer to the data slices the outer structure.
                 len( t_data_1.a ), // Number of elements to be partitioned into different threads.
                 nthreads ) 



    fmt.printf("\n")
    for i in 0 ..< len( t_data_1.a ) {
        fmt.printf( " end a_end: a[%d] = %f\n", i, t_data_1.a[i] )
    }

    // Destroy thread pool.
    thread.pool_finish(& pool)

    fmt.printf("\n ... end parallel_test_2\n\n")
}

// ****************
// parallel_test_3

parallel_test_3 :: proc () {

    fmt.printf("\n==>> Begin parallel_test_3...\n\n")

    // Init the thread pool with NThreads number of threads.
    pool : thread.Pool
    thread.pool_init( &pool, context.allocator, nthreads )

    ARRAY_LEN :: 8 // 3 // 6 // 8 // 100_000

    // Alloc arrays / slices / dynamic_arrays
    // t_data_1      := new( TData_1 )
    // defer free( t_data_1)
    t_data_1   := TData_1{ }
    t_data_1.a  = make( []f32, ARRAY_LEN )
    t_data_1.b  = make( []f32, ARRAY_LEN )
    t_data_1.c  = make( []f32, ARRAY_LEN )
    defer delete( t_data_1.a )
    defer delete( t_data_1.b )
    defer delete( t_data_1.c )

    fmt.printf("\n")
    for i in 0 ..< len( t_data_1.a ) {
        fmt.printf( "a_begin: a[%d] = %f\n", i, t_data_1.a[i] )
    }

    // For 1
    work_func_a1 :: proc ( task : thread.Task ) {
        t := ( ^ParallelInfo( TData_1 ) )( task.data )^

        // Debug
        //parallel_info_print_all( "before ", task, &t ) 
        a := t.sl.a
        b := t.sl.b
        c := t.sl.c
        a_start_off := t.a_start_off[ task.user_index ]
        a_end_off   := t.a_end_off[ task.user_index ]
        for i in a_start_off ..< a_end_off {  
            // Start parallel computation...  
            j := f32( i )
            a[i] = 1 + j
            // ...end parallel computation.  
        }

        // Debug
        // parallel_info_print_all( "after ", task, &t )
    }

    do_parallel( & pool,
                 work_func_a1,
                 & t_data_1,                      // Pointer to the data slices the outer structure.
                 len( t_data_1.a ), // Number of elements to be partitioned into different threads.
                 nthreads ) 

    fmt.printf("\n")
    for i in 0 ..< len( t_data_1.a ) {
        fmt.printf( " end a_end: a[%d] = %f\n", i, t_data_1.a[i] )
    }

    // Destroy thread pool.
    thread.pool_finish(& pool)

    fmt.printf("\n... end parallel_test_3\n\n")
}

TData_2 :: struct {
    a: ^[8]f32,   // Ptr to array of 8 elements.
    b: ^[8]f32,
    c: ^[8]f32,
    scalling_factor: f32,       // Other variables.
}


// ****************
// parallel_test_4

parallel_test_4 :: proc () {

    fmt.printf("\n==>> Begin parallel_test_4...\n\n")

    // Init the thread pool with NThreads number of threads.
    pool : thread.Pool
    thread.pool_init( &pool, context.allocator, nthreads )

    ARRAY_LEN :: 8 // 3 // 6 // 8 // 100_000

    // Alloc struct and the arrays on the stack.
    t_data_2 := TData_2{ }
    a : [8]f32
    t_data_2.a  = &a
    b : [8]f32
    t_data_2.b  = &b
    c : [8]f32
    t_data_2.c  = &c

    t_data_2.scalling_factor = 2.0

    // For 1
    work_func_a1 :: proc ( task : thread.Task ) {
        t := ( ^ParallelInfo( TData_2 ) )( task.data )^
        a := t.sl.a
        a_start_off := t.a_start_off[ task.user_index ]
        a_end_off   := t.a_end_off[ task.user_index ]

        for i in a_start_off ..< a_end_off {
            // Start parallel computation...  
            j := f32( i )
            a[ i ] = 1 + j
            // ...end parallel computation.  
        }
    }

    do_parallel( & pool,
                 work_func_a1,
                 & t_data_2,                      // Pointer to the data slices the outer structure.
                 len( t_data_2.a ), // Number of elements to be partitioned into different threads.
                 nthreads ) 

    // For 2
    work_func_a2 :: proc ( task : thread.Task ) {
        t := ( ^ParallelInfo( TData_2 ) )( task.data )^
        a := t.sl.a
        b := t.sl.b
        scalling_factor := t.sl.scalling_factor
        a_start_off := t.a_start_off[ task.user_index ]
        a_end_off   := t.a_end_off[ task.user_index ]

        for i in a_start_off ..< a_end_off {
            // Start parallel computation...  
            j := f32( i )
            b[ i ] = 1 + a[ i ] * j * scalling_factor
            // ...end parallel computation.  
        }
    }

    do_parallel( & pool,
                 work_func_a2,
                 & t_data_2,                      // Pointer to the data slices the outer structure.
                 len( t_data_2.a ), // Number of elements to be partitioned into different threads.
                 nthreads ) 

    t_data_2.scalling_factor = 3.0

    // For 2
    work_func_a3 :: proc ( task : thread.Task ) {
        t := ( ^ParallelInfo( TData_2 ) )( task.data )^
        a := t.sl.a
        b := t.sl.b
        c := t.sl.c
        scalling_factor := t.sl.scalling_factor
        a_start_off := t.a_start_off[ task.user_index ]
        a_end_off   := t.a_end_off[ task.user_index ]

        parallel_info_print_all( "before ", task, &t )

        for i in a_start_off ..< a_end_off {
            // Start parallel computation...  
            j := f32( i )
            c[ i ] += 1 + a[ i ] + b[ i ] * j * scalling_factor
            c[ i ] = math.sin( c[ i ] )
            // ...end parallel computation.  
        }
    }

    do_parallel( & pool,
                 work_func_a3,
                 & t_data_2,                      // Pointer to the data slices the outer structure.
                 len( t_data_2.a ), // Number of elements to be partitioned into different threads.
                 nthreads ) 

    
    fmt.printf("\n")
    for i in 0 ..< len( t_data_2.c ) {
        fmt.printf( " end a_end: c[%d] = %f\n", i, t_data_2.c[ i ] )
    }

    // Destroy thread pool.
    thread.pool_finish(& pool)

    fmt.printf("\n... end parallel_test_4\n\n")
}

