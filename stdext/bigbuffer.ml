(*
 * Copyright (C) 2007 XenSource Ltd.
 * Author Vincent Hanquez <vincent@xensource.com>
 *)

type t = {
	mutable cells: string option array;
	mutable index: int64;
}

let cell_size = 4096
let default_array_len = 16

let make () = { cells = Array.make default_array_len None; index = 0L }

let length bigbuf = bigbuf.index

let get bigbuf n =
	let array_offset = Int64.to_int (Int64.div n (Int64.of_int cell_size)) in
	let cell_offset = Int64.to_int (Int64.rem n (Int64.of_int cell_size)) in
	match bigbuf.cells.(array_offset) with
	| None -> "".[0]
	| Some buf -> buf.[cell_offset]

let rec append_substring bigbuf s offset len =
	let array_offset = Int64.to_int (Int64.div bigbuf.index (Int64.of_int cell_size)) in
	let cell_offset = Int64.to_int (Int64.rem bigbuf.index (Int64.of_int cell_size)) in

	if Array.length bigbuf.cells <= array_offset then (
		(* we need to reallocate the array *)
		bigbuf.cells <- Array.append bigbuf.cells (Array.make default_array_len None)
	);

	let buf = match bigbuf.cells.(array_offset) with
	| None ->
		let newbuf = String.create cell_size in
		bigbuf.cells.(array_offset) <- Some newbuf;
		newbuf
	| Some buf ->
		buf
		in
	if len + cell_offset <= cell_size then (
		String.blit s offset buf cell_offset len;
		bigbuf.index <- Int64.add bigbuf.index (Int64.of_int len);
	) else (
		let rlen = cell_size - cell_offset in
		String.blit s offset buf cell_offset rlen;
		bigbuf.index <- Int64.add bigbuf.index (Int64.of_int rlen);
		append_substring bigbuf s (offset + rlen) (len - rlen)
	);
	()

let to_fct bigbuf f =
	let array_offset = Int64.to_int (Int64.div bigbuf.index (Int64.of_int cell_size)) in
	let cell_offset = Int64.to_int (Int64.rem bigbuf.index (Int64.of_int cell_size)) in

	(* copy all complete cells *)
	for i = 0 to array_offset - 1
	do
		match bigbuf.cells.(i) with
		| None      -> (* ?!?!? *) ()
		| Some cell -> f cell
	done;

	(* copy last cell *)
	begin match bigbuf.cells.(array_offset) with
	| None      -> (* ?!?!?! *) ()
	| Some cell -> f (String.sub cell 0 cell_offset)
	end;
	()

let to_string bigbuf =
	if bigbuf.index > (Int64.of_int Sys.max_string_length) then
		failwith "cannot allocate string big enough";

	let dest = String.create (Int64.to_int bigbuf.index) in
	let destoff = ref 0 in
	to_fct bigbuf (fun s ->
		let len = String.length s in
		String.blit s 0 dest !destoff len;
		destoff := !destoff + len
	);
	dest

let to_stream bigbuf outchan =
	to_fct bigbuf (fun s -> output_string outchan s)
