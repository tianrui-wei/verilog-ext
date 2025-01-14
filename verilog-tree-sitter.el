;;; verilog-tree-sitter.el --- Verilog Tree-sitter  -*- lexical-binding: t -*-

;; Copyright (C) 2022-2023 Gonzalo Larumbe

;; Author: Gonzalo Larumbe <gonzalomlarumbe@gmail.com>
;; URL: https://github.com/gmlarumbe/verilog-ext
;; Version: 0.0.0
;; Keywords: Verilog, IDE, Tools
;; Package-Requires: ((emacs "28.1"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Verilog Tree-sitter

;;; Code:


(require 'treesit)


;;; Utils
(defun verilog-ts--node-at-point ()
  "Return tree-sitter node at point."
  (treesit-node-at (point) 'verilog))

(defun verilog-ts--node-has-parent-recursive (node node-type)
  "Return non-nil if NODE is part of NODE-TYPE in the hierarchy."
  (treesit-parent-until
   node
   (lambda (node)
     (string= (treesit-node-type node) node-type))))

;; TODO: Only works if point is placed before the identifier
(defun verilog-ts--node-identifier-name (node)
  "Return identifier name of NODE."
  (treesit-node-text (treesit-search-forward
                      node
                      "simple_identifier"
                      nil
                      t)
                     :no-prop))

  ;; TODO: Only works if point is at the beginning of a symbol!
(defun verilog-ts--highest-node-at-pos (pos)
  "Return highest node in the hierarchy that starts at POS.
Snippet fetched from `treesit--indent-1'."
  (let* ((smallest-node (verilog-ts--node-at-point))
         (node (treesit-parent-while
                smallest-node
                (lambda (node)
                  (eq pos (treesit-node-start node))))))
    node))

(defun verilog-ts--node-at-bol ()
  "Return node at first non-blank character of current line.
Snippet fetched from `treesit--indent-1'."
  (let* ((bol (save-excursion
                (forward-line 0)
                (skip-chars-forward " \t")
                (point)))
         (smallest-node
          (cond ((null (treesit-parser-list)) nil)
                ((eq 1 (length (treesit-parser-list)))
                 (treesit-node-at bol))
                ((treesit-language-at (point))
                 (treesit-node-at bol (treesit-language-at (point))))
                (t (treesit-node-at bol))))
         (node (treesit-parent-while
                smallest-node
                (lambda (node)
                  (eq bol (treesit-node-start node))))))
    node))

;; INFO: Only works for brackets and begin/end now
(defun verilog-ts-forward-sexp ()
  "Move forward across expressions."
  (interactive)
  (if (member (following-char) '(?\( ?\{ ?\[))
      (forward-sexp 1)
    (let* ((node (verilog-ts--node-at-point))  ; begin/end
           (parent (treesit-node-parent node)) ; seq_block
           (beg (treesit-node-start parent))
           (end (treesit-node-end parent))
           (text (treesit-node-text node :no-props)))
      (goto-char end))))

;; INFO: Only works for brackets and begin/end now
(defun verilog-ts-backward-sexp ()
  "Move backward across expressions."
  (interactive)
  (if (member (preceding-char) '(?\) ?\} ?\]))
      (backward-sexp 1)
    (let* ((node (verilog-ts--node-at-point))  ; begin/end
           (parent (treesit-node-parent node)) ; seq_block
           (beg (treesit-node-start parent))
           (end (treesit-node-end parent))
           (text (treesit-node-text node :no-props)))
      (goto-char beg))))

(defun verilog-ts-module-at-point ()
  "Return name of module at point."
  (interactive)
  (let ((node-at-point (treesit-node-at (point)))
        module-node module-at-point)
    (setq module-node (verilog-ts--node-has-parent-recursive node-at-point "module_instantiation"))
    ;; (setq module-at-point (treesit-node-text module-node :no-prop))
    (setq module-at-point (treesit-node-text (treesit-search-forward
                                              module-node
                                              "simple_identifier"
                                              nil
                                              nil)
                                             :no-prop))))

(defun verilog-ts-nodes-current-buffer (pred)
  "Return node names that satisfy PRED in current buffer."
  (interactive)
  (let* ((root-node (treesit-buffer-root-node))
         (pred-nodes (cdr (treesit-induce-sparse-tree root-node pred)))
         names-list)
    (dolist (node pred-nodes)
      (push (verilog-ts--node-identifier-name (car node)) names-list))
    (seq-reverse names-list)))

(defun verilog-ts-class-attributes ()
  "Return class attributes of current file."
  (interactive)
  (verilog-ts-nodes-current-buffer "class_property"))

(defun verilog-ts-class-methods ()
  "Return class methods of current file."
  (interactive)
  (verilog-ts-nodes-current-buffer "class_method"))

(defun verilog-ts-class-constraints ()
  "Return class constraints of current file."
  (interactive)
  (verilog-ts-nodes-current-buffer "constraint_declaration"))


;;; Font-lock
;; There are some keywords that are not recognized by tree-sitter grammar.
;; For these ones, use regexp matching patterns inside tree-sitter (:match "^foo$")
(defconst verilog-ts-keywords
  '("alias"
    "and"
    "assert"
    "assign"
    "assume"
    "before"
    "binsof"
    "break"
    "checker"
    "class"
    "class"
    "config"
    "const"
    "constraint"
    "covergroup"
    "coverpoint"
    "cross"
    "default"
    "defparam"
    "do"
    "else"
    "endcase"
    "endchecker"
    "endclass"
    "endconfig"
    "endfunction"
    "endgenerate"
    "endgroup"
    "endinterface"
    "endmodule"
    "endpackage"
    "endprogram"
    "endproperty"
    "endsequence"
    "endtask"
    "enum"
    "extends"
    "extern"
    "final"
    "first_match"
    "for"
    "foreach"
    "forever"
    "fork"
    "forkjoin"
    "function"
    "generate"
    "genvar"
    "if"
    "iff"
    "illegal_bins"
    "implements"
    "import"
    "initial"
    "inside"
    "interconnect"
    "interface"
    "intersect"
    "join"
    "join_any"
    "join_none"
    "local"
    "localparam"
    "modport"
    "new"
    "null"
    "option"
    "or"
    "package"
    "packed"
    "parameter"
    "program"
    "property"
    "pure"
    "randomize"
    "repeat"
    "return"
    "sequence"
    "showcancelled"
    "soft"
    "solve"
    "struct"
    "super"
    "tagged"
    "task"
    "timeprecision"
    "timeunit"
    "type"
    "typedef"
    "union"
    "unique"
    "virtual"
    "wait"
    "while"
    "with"
    (always_keyword)       ; always, always_comb, always_latch, always_ff
    (bins_keyword)         ; bins, illegal_bins, ignore_bins
    (case_keyword)         ; case, casez, casex
    (class_item_qualifier) ; static, protected, local
    (edge_identifier)      ; posedge, negedge, edge
    (lifetime)             ; static, automatic
    (module_keyword)       ; module, macromodule
    (random_qualifier)     ; rand, randc
    (unique_priority)))    ; unique, unique0, priority

(defconst verilog-ts-operators-arithmetic
  '("+" "-" "*" "/" "%" "**"))

(defconst verilog-ts-operators-relational
  '("<" "<=" ">" ">="))

(defconst verilog-ts-operators-equality
  '("===" "!==" "==" "!="))

(defconst verilog-ts-operators-logical
  '("&&" "||" "!"))

(defconst verilog-ts-operators-bitwise
  '("~" "&" "~&" "|" "~|" "^" "~^"))

(defconst verilog-ts-operators-shift
  '("<<" ">>" "<<<" ">>>"))

(defconst verilog-ts-punctuation
  '(";" ":" "," "::"
    "=" "?" "|=" "&=" "^="
    "|->" "|=>" "->"
    (inc_or_dec_operator) ; ++, --
    ":=" ":/" "-:" "+:"))

(defconst verilog-ts-directives
  '("directive_include" "directive_define" "directive_ifdef" "directive_ifndef"
    "directive_timescale" "directive_default_nettype" "directive_elsif"
    "directive_undef" "directive_resetall" "directive_undefineall" "directive_endif"
    "directive_else" "directive_unconnected_drive" "directive_celldefine"
    "directive_endcelldefine" "directive_end_keywords" "directive_unconnected_drive"
    "directive_line" "directive_begin_keywords"))

(defun verilog-ts--fontify-width-num (node override start end &rest _)
  "Fontify an identifier node if it is a variable.
Don't fontify if it is a function identifier.  For NODE,
OVERRIDE, START, END, and ARGS, see `treesit-font-lock-rules'."
  (let* ((text (treesit-node-text node))
         (apostrophe-offset (string-match "'" text))
         (type-offset (string-match "[hHdDxXbBoO]" text))
         apostrophe-pos type-pos)
    (when (and apostrophe-offset type-offset)
      (setq apostrophe-pos (+ (treesit-node-start node) apostrophe-offset))
      (setq type-pos (+ (treesit-node-start node) type-offset))
      ;; Width
      (treesit-fontify-with-override
       (treesit-node-start node) apostrophe-pos
       'verilog-ext-font-lock-width-num-face
       override start end)
      ;; Apostrophe
      (treesit-fontify-with-override
       apostrophe-pos (1+ apostrophe-pos)
       'verilog-ext-font-lock-punctuation-face
       override start end)
      ;; Radix
      (treesit-fontify-with-override
       type-pos (1+ type-pos)
       'verilog-ext-font-lock-width-type-face
       override start end))))

(defvar verilog--treesit-settings
  (treesit-font-lock-rules
   :feature 'comment
   :language 'verilog
   '((comment) @font-lock-comment-face)

   :feature 'string
   :language 'verilog
   '((string_literal) @font-lock-string-face
     (double_quoted_string) @font-lock-string-face)

   :feature 'all
   :language 'verilog
   '(;; Arrays
     ((packed_dimension
       (constant_range) @verilog-ext-font-lock-braces-content-face))
     ((unpacked_dimension
       (constant_range) @verilog-ext-font-lock-braces-content-face))
     (select1
      (constant_range) @verilog-ext-font-lock-braces-content-face)
     ((unpacked_dimension
       (constant_expression) @verilog-ext-font-lock-braces-content-face))
     (bit_select1
      (expression) @verilog-ext-font-lock-braces-content-face)
     (constant_select1
      (constant_expression) @verilog-ext-font-lock-braces-content-face)
     (constant_bit_select1
      (constant_expression) @verilog-ext-font-lock-braces-content-face)
     (indexed_range
      (expression) @verilog-ext-font-lock-braces-content-face
      (constant_expression) @verilog-ext-font-lock-braces-content-face)
     ;; Timeunit
     ((time_unit) @font-lock-constant-face)
     ;; Enum labels
     (enum_name_declaration
      (enum_identifier
       (simple_identifier) @font-lock-constant-face))
     ;; Parameters
     (parameter_value_assignment
      (list_of_parameter_assignments
       (named_parameter_assignment
        (parameter_identifier (simple_identifier) @verilog-ext-font-lock-port-connection-face))))
     ;; Interface signals (members)
     (expression
      (primary
       (simple_identifier) @verilog-ext-font-lock-dot-name-face
       (select1
        (member_identifier
         (simple_identifier)))))
     ;; Interface signals with index
     (expression
      (primary
       (simple_identifier) @verilog-ext-font-lock-dot-name-face
       (constant_bit_select1)))
     ;; Case item label (not radix)
     (case_item_expression
      (expression
       (primary (simple_identifier) @font-lock-constant-face)))
     ;; Attributes
     (["(*" "*)"] @font-lock-constant-face)
     (attribute_instance
      (attr_spec (simple_identifier) @verilog-ext-font-lock-xilinx-attributes-face))
     ;; Typedef class
     ("typedef" "class" (simple_identifier) @font-lock-constant-face)
     ;; Coverpoint label
     (cover_point
      (cover_point_identifier (simple_identifier) @font-lock-constant-face))
     ;; inside {[min_range:max_range]}
     ((open_value_range) @font-lock-constant-face)
     ;; Loop variables (foreach[i])
     (loop_variables1
      (index_variable_identifier
       (index_variable_identifier (simple_identifier) @font-lock-constant-face)))
     ;; Numbers with radix (4'hF)
     ((integral_number) @verilog-ts--fontify-width-num)
     )

   :feature 'keyword
   :language 'verilog
   `((["begin" "end" "this"] @verilog-ext-font-lock-grouping-keywords-face)
     ([,@verilog-ts-keywords] @font-lock-keyword-face))

   :feature 'operator
   :language 'verilog
   `(([,@verilog-ts-operators-arithmetic] @verilog-ext-font-lock-punctuation-bold-face)
     ([,@verilog-ts-operators-relational] @verilog-ext-font-lock-punctuation-face)
     ([,@verilog-ts-operators-equality] @verilog-ext-font-lock-punctuation-face)
     ([,@verilog-ts-operators-shift] @verilog-ext-font-lock-punctuation-face)
     ([,@verilog-ts-operators-bitwise] @verilog-ext-font-lock-punctuation-bold-face)
     ([,@verilog-ts-operators-logical] @verilog-ext-font-lock-punctuation-bold-face))

   :feature 'punctuation
   :language 'verilog
   `(([,@verilog-ts-punctuation] @verilog-ext-font-lock-punctuation-face)
     (["."] @verilog-ext-font-lock-punctuation-bold-face)
     (["(" ")"] @verilog-ext-font-lock-parenthesis-face)
     (["[" "]"] @verilog-ext-font-lock-brackets-face)
     (["{" "}"] @verilog-ext-font-lock-curly-brackets-face)
     (["@" "#" "##"] @verilog-ext-font-lock-time-event-face))

   :feature 'directives-macros
   :language 'verilog
   `(([,@verilog-ts-directives] @verilog-ext-font-lock-preprocessor-face)
     (text_macro_identifier
      (simple_identifier) @verilog-ext-font-lock-preprocessor-face))

   :feature 'declaration
   :language 'verilog
   '((module_header
      (module_keyword) @font-lock-keyword-face
      (simple_identifier) @font-lock-function-name-face)
     (interface_declaration
      (interface_ansi_header
       (interface_identifier (simple_identifier) @font-lock-function-name-face)))
     (package_declaration
      (package_identifier (simple_identifier) @font-lock-function-name-face))
     (class_declaration
      (class_identifier) @font-lock-function-name-face) ; Class name
     (class_declaration
      (class_type
       (class_identifier (simple_identifier) @font-lock-type-face))) ; Parent class
     ;; Ports
     (["input" "output" "inout" "ref"] @verilog-ext-font-lock-direction-face)
     ;; Ports with user types
     (ansi_port_declaration
      (net_port_header1
       (net_port_type1
        (simple_identifier) @font-lock-type-face)))
     ;; Interfaces with modports
     (ansi_port_declaration
      (interface_port_header
       (interface_identifier
        (simple_identifier) @verilog-ext-font-lock-dot-name-face)
       (modport_identifier
        (modport_identifier
         (simple_identifier) @verilog-ext-font-lock-modport-face))))
     )

   :feature 'instance
   :language 'verilog
   '((module_or_generate_item
      (module_instantiation (simple_identifier) @verilog-ext-font-lock-module-face))
     (module_or_generate_item
      (program_instantiation
       (program_identifier (simple_identifier) @verilog-ext-font-lock-module-face)))
     (module_or_generate_item
      (interface_instantiation
       (interface_identifier (simple_identifier) @verilog-ext-font-lock-module-face)))
     (hierarchical_instance
      (name_of_instance
       (instance_identifier (simple_identifier) @verilog-ext-font-lock-instance-face)))
     (hierarchical_instance
      (list_of_port_connections
       (named_port_connection
        (port_identifier (simple_identifier) @verilog-ext-font-lock-port-connection-face))))
     (checker_instantiation ; Some module/interface instances might wrongly be detected as checkers
      (checker_identifier (simple_identifier) @verilog-ext-font-lock-module-face)
      (name_of_instance
       (instance_identifier (simple_identifier) @verilog-ext-font-lock-instance-face)))
     (checker_instantiation
      (formal_port_identifier (simple_identifier) @verilog-ext-font-lock-port-connection-face))
     )

   :feature 'types
   :language 'verilog
   `(([(integer_vector_type) ; bit, logic, reg
       (integer_atom_type)   ; byte, shortint, int, longint, integer, time
       (non_integer_type)    ; shortreal, real, realtime
       (net_type)]           ; supply0, supply1, tri, triand, trior, trireg, tri0, tri1, uwire, wire, wand, wor
      @font-lock-type-face)
     (["void'" ; void cast of task called as a function
       (data_type_or_void)]
      @font-lock-type-face)
     (data_type_or_implicit1
      (data_type
       (simple_identifier) @font-lock-type-face))
     (data_type
      (class_type
       (class_identifier (simple_identifier) @font-lock-type-face)))
     (type_assignment
      (simple_identifier) @font-lock-type-face)
     ;; User type variable declaration
     (net_declaration
      (simple_identifier) @font-lock-type-face)
     ;; Enum base type
     (enum_base_type) @font-lock-type-face
     ;; Virtual interface handles
     (data_type_or_implicit1
      (data_type
       (interface_identifier (simple_identifier) @font-lock-type-face)))
     ;; Others
     (["string" "event" "signed" "unsigned"] @font-lock-type-face)
     )

   :feature 'definition
   :language 'verilog
   '((function_body_declaration
      (function_identifier
       (function_identifier (simple_identifier) @font-lock-function-name-face)))
     (task_identifier
      (task_identifier (simple_identifier) @font-lock-function-name-face))
     (function_prototype
      (data_type_or_void)
      (function_identifier
       (function_identifier (simple_identifier) @font-lock-function-name-face)))
     (class_scope ; Definition of extern defined methods
      (class_type
       (class_identifier (simple_identifier) @verilog-ext-font-lock-dot-name-face)))
     )

   :feature 'funcall
   :language 'verilog
   ;; System task/function
   '(((system_tf_identifier) @font-lock-builtin-face)
     ;; Method calls
     (method_call_body
      (method_identifier
       (method_identifier (simple_identifier) @font-lock-doc-face))))
   ))


;;; Indent
(defun verilog-ts--unit-scope (&rest _)
  "A tree-sitter simple indent matcher.
Matches if point is at $unit scope."
  (let* ((node (verilog-ts--node-at-bol))
         (parent (treesit-node-parent node))
         (root (treesit-buffer-root-node)))
    (or (treesit-node-eq node root)
        (treesit-node-eq parent root))))

(defun verilog-ts--blank-line (&rest _)
  "A tree-sitter simple indent matcher.
Matches if point is at a blank line."
  (let ((node (verilog-ts--node-at-bol)))
    (unless node
      t)))

(defun verilog-ts--uvm-field-macro (&rest _)
  "A tree-sitter simple indent matcher.
Matches if point is at uvm_field_* macro.
Snippet fetched from `treesit--indent-1'."
  (let* ((bol (save-excursion
                (forward-line 0)
                (skip-chars-forward " \t")
                (point)))
         (leaf-node (treesit-node-at bol))
         (node (verilog-ts--node-has-parent-recursive leaf-node "text_macro_usage"))
         (node-text (when node
                      (treesit-node-text node :no-props))))
    (when (and node-text
               (eq 0 (string-match "`uvm_field_" node-text)))
      node-text)))

(defun verilog-ts--default-indent (&rest _)
  "A tree-sitter simple indent matcher.
Always return non-nil."
  t)


(defvar verilog-ts--indent-rules
  `((verilog
     ;; Unit scope
     (verilog-ts--unit-scope point-min 0) ; Place first for highest precedence
     ;; Comments
     ((and (node-is "comment")
           verilog-ts--unit-scope)
      point-min 0)
     ((and (node-is "comment")
           (parent-is "conditional_statement"))
      parent-bol 0)
     ((and (node-is "comment")
           (parent-is "list_of_port_connections"))
      parent-bol 0)
     ((node-is "comment") parent-bol 4)
     ;; Procedural
     ((node-is "statement_or_null") parent-bol 4)
     ((node-is "case_item") parent-bol 4)
     ((node-is "block_item_declaration") parent-bol 4)     ; Procedural local variables declaration
     ((node-is "tf_item_declaration") parent-bol 4)        ; Procedural local variables in tasks declaration
     ((node-is "function_statement_or_null") parent-bol 4) ; Procedural statement in a function
     ((node-is "super") parent-bol 4)
     ;; ANSI Port/parameter declaration
     ((node-is "ansi_port_declaration") parent-bol 4)
     ((node-is "parameter_port_declaration") parent-bol 4)
     ((node-is "module_or_generate_item") parent-bol 4)
     ((node-is "interface_or_generate_item") parent-bol 4)
     ((node-is "list_of_param_assignments") parent-bol 4) ; First instance parameter (without parameter keyword)
     ((node-is "parameter_port_declaration") parent-bol 4) ; First instance parameter (without parameter keyword)
     ;; import packages
     ((and (node-is "package_or_generate_item_declaration")
           (parent-is "package_declaration"))
      parent-bol 4)
     ;; Instance port/parameters
     ((node-is "list_of_port_connections") parent-bol 4)      ; First port connection
     ((node-is "named_port_connection") parent-bol 0)         ; Rest of ports with respect to first port
     ((node-is "list_of_parameter_assignments") parent-bol 4) ; First instance parameter
     ((node-is "named_parameter_assignment") parent-bol 0)    ; Rest of instance parameters with respect to first parameter
     ;; Closing
     ((or (node-is "end")
          (node-is "else")         ; Parent is 'if
          (node-is "join_keyword") ; Parent is 'fork
          (node-is "}")
          (node-is ")")
          (node-is "]"))
      parent-bol 0)
     ;; Opening
     ((or (node-is "{")
          (node-is "("))
      parent-bol 0)
     ;; Macros
     ((and (node-is "class_item") ; Place before (node-is "class_item") to match with higher precedence
           verilog-ts--uvm-field-macro)
      parent-bol 8)
     ;; Others
     ((node-is "class_item") parent-bol 4)
     ((node-is "timeunits_declaration") parent-bol 4)
     ((node-is "tf_port_item1") grand-parent 4)       ; Task ports in multiple lines
     ((node-is "tf_port_list") parent 4)              ; Task ports in multiple lines (first line)
     ((node-is "constraint_block_item") parent-bol 4)
     ((node-is "enum_name_declaration") parent-bol 4)
     ((node-is "generate_region") parent-bol 4)
     ((node-is "hierarchical_instance") parent-bol 0) ; Instance name in separate line
     ;; Blank lines
     (verilog-ts--blank-line parent-bol 4)
     )))


;;; Imenu
(defun verilog-ts--defun-name (node)
  "Return the defun name of NODE.
Return nil if there is no name or if NODE is not a defun node."
  (verilog-ts--node-identifier-name node))


;;; Navigation
(defconst verilog-ts--defun-type-regexp
  (regexp-opt '("module_declaration"
                "interface_ansi_header"
                "class_declaration"
                "function_declaration"
                "task_declaration"
                "class_method")))

;;; Major-mode
(defvar-keymap verilog-ts-mode-map
  :doc "Keymap for SystemVerilog language with tree-sitter"
  :parent verilog-mode-map
  "TAB" #'indent-for-tab-command)

(defvar verilog-ts-mode-syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?\\ "\\"      table)
    (modify-syntax-entry ?+  "."      table)
    (modify-syntax-entry ?-  "."      table)
    (modify-syntax-entry ?=  "."      table)
    (modify-syntax-entry ?%  "."      table)
    (modify-syntax-entry ?<  "."      table)
    (modify-syntax-entry ?>  "."      table)
    (modify-syntax-entry ?&  "."      table)
    (modify-syntax-entry ?|  "."      table)
    (modify-syntax-entry ?`  "."      table)
    (modify-syntax-entry ?_  "_"      table)
    (modify-syntax-entry ?\' "."      table)
    (modify-syntax-entry ?/  ". 124b" table)
    (modify-syntax-entry ?*  ". 23"   table)
    (modify-syntax-entry ?\n "> b"    table)
    table)
  "Syntax table used in Verilog mode buffers.")

;;;###autoload
(define-derived-mode verilog-ts-mode verilog-mode "SystemVerilog"
  "Major mode for editing SystemVerilog files, using tree-sitter library."
  :syntax-table verilog-ts-mode-syntax-table
  ;; Treesit
  (when (treesit-ready-p 'verilog)
    (treesit-parser-create 'verilog)
    ;; Font-lock.
    (setq font-lock-defaults nil) ; Disable `verilog-mode' font-lock/indent config
    (setq-local treesit-font-lock-feature-list
                '((comment string)
                  (keyword operator)
                  (directives-macros types punctuation declaration definition)
                  (all funcall instance)))
    (setq-local treesit-font-lock-settings verilog--treesit-settings)
    ;; Indent.
    (setq-local indent-line-function nil)
    (setq-local comment-indent-function nil)
    (setq-local treesit-simple-indent-rules verilog-ts--indent-rules)
    ;; Navigation.
    (setq-local treesit-defun-type-regexp verilog-ts--defun-type-regexp)
    ;; Imenu.
    (setq-local treesit-defun-name-function #'verilog-ts--defun-name)
    (setq-local treesit-simple-imenu-settings
                `(("Class" "\\`class_declaration\\'" nil nil)
                  ("Task" "\\`task_declaration\\'" nil nil)
                  ("Func" "\\`function_declaration\\'" nil nil)))
    ;; Setup.
    (treesit-major-mode-setup)))


;;; Provide
(provide 'verilog-tree-sitter)

;;; verilog-tree-sitter.el ends here

