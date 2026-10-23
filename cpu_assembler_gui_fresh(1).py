import tkinter as tk
from tkinter import ttk, filedialog, messagebox
import os
import re
import threading
import queue
import time
import json
import subprocess
import shutil

try:
    import serial
    from serial import SerialException
    from serial.tools import list_ports
except ImportError:
    serial = None
    SerialException = Exception
    list_ports = None

from assembler import assemble_program


class CPUAssemblerIDE:
    """
    32-bit CPU Assembler + FPGA UART Monitor.

    Requires:
        pip install pyserial

    Expected FPGA UART:
        Baud: 921600
        Format: 8-N-1

    Debug packet:
        Byte 0       : 0xAA
        Bytes 1..4   : PC, MSB first
        Bytes 5..132 : R0..R31, 4 bytes each, MSB first
        Byte 133     : HALT status
    """

    INSTRUCTIONS = {
        "MOVI": "MOVI Rt, immediate",
        "ADD": "ADD Rd, Rs, Rt",
        "SUB": "SUB Rd, Rs, Rt",
        "AND": "AND Rd, Rs, Rt",
        "OR": "OR Rd, Rs, Rt",
        "SLT": "SLT Rd, Rs, Rt",
        "MUL": "MUL Rd, Rs, Rt",
        "MOV": "MOV Rd, Rs",
        "ADDI": "ADDI Rt, Rs, immediate",
        "SUBI": "SUBI Rt, Rs, immediate",
        "SLTI": "SLTI Rt, Rs, immediate",
        "LW": "LW Rt, offset(Rs)",
        "SW": "SW Rt, offset(Rs)",
        "BEQZ": "BEQZ Rs, label",
        "BNEQZ": "BNEQZ Rs, label",
        "J": "J label",
        "HLT": "HLT",
    }

    C={"bg":"#EDEDED","panel":"#F3F3F3","panel2":"#E5E5E5","editor":"#FFFFFF","border":"#BDBDBD","text":"#202020","muted":"#666666","accent":"#2F5597","green":"#008000","red":"#A00000","yellow":"#8A5A00","purple":"#800080","line":"#D0D0D0","white":"#FFFFFF","code":"#FFFFFF","code_text":"#004080"}

    def __init__(self, root):
        self.root = root
        self.root.title("32-bit CPU Assembler IDE")
        self.root.geometry("1450x900")
        self.root.minsize(1050, 700)
        self.root.configure(bg=self.C["bg"])

        self.current_file = None
        self.machine_code = []
        self.serial_port = None
        self.reader_thread = None
        self.reader_stop = threading.Event()
        self.serial_lock = threading.Lock()
        self.rx_queue = queue.Queue()

        self.packet_buffer = bytearray()
        self.packet_count = 0
        self.last_packet_time = None
        self.last_error = None

        self.port_var = tk.StringVar()
        self.baud_var = tk.StringVar(value="921600")
        self.connection_var = tk.StringVar(value="Disconnected")
        self.cpu_status_var = tk.StringVar(value="OFFLINE")
        self.pc_var = tk.StringVar(value="0x00000000")
        self.halt_var = tk.StringVar(value="—")
        self.program_var = tk.StringVar(value="No program assembled")
        self.packet_var = tk.StringVar(value="No packet received")
        self.cursor_var = tk.StringVar(value="Ln 1, Col 1")
        self.file_var = tk.StringVar(value="Untitled.asm")
        self.mode_var = tk.StringVar(value="Simulation")
        self.sim_command_var = tk.StringVar(value="run_simulation_fresh.bat")
        self.sim_result_var = tk.StringVar(value="simulation_result.json")
        self.sim_process = None
        self.sim_thread = None
        self.sim_stop = threading.Event()
        self.simulation_timeout = 120


        self.create_style()
        self.create_menu()
        self.create_header()
        self.create_serial_bar()
        self.create_main_area()
        self.create_bottom_area()
        self.create_status_bar()
        self.bind_shortcuts()

        self.refresh_ports()
        # Start with a completely empty assembly editor.
        self.process_rx_queue()
        self.update_cursor_position()

        self.root.protocol("WM_DELETE_WINDOW", self.close_app)

    # =========================================================
    # STYLE
    # =========================================================

    def create_style(self):
        style=ttk.Style(self.root)
        try: style.theme_use("clam")
        except tk.TclError: pass
        style.configure(".",background=self.C["bg"],foreground=self.C["text"],font=("Segoe UI",9))
        style.configure("TFrame",background=self.C["bg"])
        style.configure("TLabel",background=self.C["bg"],foreground=self.C["text"])
        style.configure("Panel.TLabel",background=self.C["panel"],foreground=self.C["text"])
        style.configure("Muted.TLabel",background=self.C["bg"],foreground=self.C["muted"])
        style.configure("PanelMuted.TLabel",background=self.C["panel"],foreground=self.C["muted"])
        style.configure("Title.TLabel",background=self.C["bg"],foreground="#17365D",font=("Segoe UI",14,"bold"))
        style.configure("Subtitle.TLabel",background=self.C["bg"],foreground="#666666",font=("Segoe UI",8))
        style.configure("TButton",padding=(8,3),relief="raised",borderwidth=1,background="#E6E6E6",foreground="#202020",font=("Segoe UI",9))
        style.map("TButton",background=[("active","#D6E4F0"),("pressed","#C7D7E7")])
        style.configure("Toolbar.TButton",padding=(7,2),relief="raised",borderwidth=1,background="#E9E9E9",foreground="#202020",font=("Segoe UI",8))
        style.map("Toolbar.TButton",background=[("active","#D8E6F3"),("pressed","#C8D8E8")])
        style.configure("Primary.TButton",padding=(9,3),relief="raised",borderwidth=1,background="#DCE6F1",foreground="#17365D",font=("Segoe UI",9,"bold"))
        style.map("Primary.TButton",background=[("active","#C9DBED"),("pressed","#B9CEE3")])
        style.configure("TCombobox",fieldbackground="#FFFFFF",background="#E6E6E6",foreground="#202020",arrowcolor="#404040",padding=2)
        style.map("TCombobox",fieldbackground=[("readonly","#FFFFFF")])
        style.configure("TPanedwindow",background="#B8B8B8")
        style.configure("TNotebook",background="#D9D9D9",borderwidth=1)
        style.configure("TNotebook.Tab",background="#D9D9D9",foreground="#303030",padding=(10,3),font=("Segoe UI",8))
        style.map("TNotebook.Tab",background=[("selected","#FFFFFF")],foreground=[("selected","#17365D")])
        style.configure("Treeview",background="#FFFFFF",fieldbackground="#FFFFFF",foreground="#222222",rowheight=22,borderwidth=1,font=("Segoe UI",9))
        style.map("Treeview",background=[("selected","#C7D7E7")],foreground=[("selected","#17365D")])
        style.configure("Treeview.Heading",background="#E5E5E5",foreground="#333333",relief="raised",font=("Segoe UI",8,"bold"))
        style.configure("TSeparator",background="#B8B8B8")
    def create_menu(self):
        menu=tk.Menu(self.root,bg="#F0F0F0",fg="#202020",activebackground="#C7D7E7",activeforeground="#17365D",tearoff=False)
        def sub(): return tk.Menu(menu,tearoff=False,bg="#F0F0F0",fg="#202020",activebackground="#C7D7E7",activeforeground="#17365D")
        m=sub(); m.add_command(label="New",command=self.new_file,accelerator="Ctrl+N"); m.add_command(label="Open...",command=self.open_file,accelerator="Ctrl+O"); m.add_command(label="Save",command=self.save_file,accelerator="Ctrl+S"); m.add_command(label="Save As...",command=self.save_as); m.add_separator(); m.add_command(label="Exit",command=self.close_app); menu.add_cascade(label="File",menu=m)
        m=sub(); m.add_command(label="Undo",command=lambda:self.editor.event_generate("<<Undo>>"),accelerator="Ctrl+Z"); m.add_command(label="Redo",command=lambda:self.editor.event_generate("<<Redo>>"),accelerator="Ctrl+Y"); m.add_separator(); m.add_command(label="Cut",command=lambda:self.editor.event_generate("<<Cut>>")); m.add_command(label="Copy",command=lambda:self.editor.event_generate("<<Copy>>")); m.add_command(label="Paste",command=lambda:self.editor.event_generate("<<Paste>>")); menu.add_cascade(label="Edit",menu=m)
        m=sub(); m.add_command(label="Project Window",command=lambda:self.status("Project window active")); m.add_command(label="CPU Monitor",command=lambda:self.status("CPU monitor active")); m.add_command(label="Build Output",command=lambda:self.output_notebook.select(self.build_tab)); menu.add_cascade(label="View",menu=m)
        m=sub(); m.add_command(label="Assemble",command=self.assemble,accelerator="F5"); m.add_command(label="Send to FPGA",command=self.assemble_and_send,accelerator="F6"); m.add_command(label="Run Simulation",command=self.run_simulation,accelerator="F7"); m.add_separator(); m.add_command(label="Project Settings...",command=self.show_simulation_settings); menu.add_cascade(label="Project",menu=m)
        m=sub(); m.add_command(label="Run Simulation",command=self.run_simulation,accelerator="F7"); m.add_command(label="Clear CPU Monitor",command=self.clear_monitor); m.add_command(label="Serial Monitor",command=self.show_serial_log); menu.add_cascade(label="Debug",menu=m)
        m=sub(); m.add_command(label="Refresh COM Ports",command=self.refresh_ports); m.add_command(label="Instruction Set",command=self.show_instruction_reference); m.add_command(label="Simulation Settings...",command=self.show_simulation_settings); menu.add_cascade(label="Tools",menu=m)
        m=sub(); m.add_command(label="About",command=self.show_about); menu.add_cascade(label="Help",menu=m)
        self.root.config(menu=menu)
    def create_header(self):
        frame=tk.Frame(self.root,bg="#D9E2F3",height=34,relief="raised",bd=1); frame.pack(fill=tk.X); frame.pack_propagate(False)
        tk.Label(frame,text="CPU Assembler IDE",bg="#D9E2F3",fg="#17365D",font=("Segoe UI",10,"bold")).pack(side=tk.LEFT,padx=9)
        tk.Label(frame,text="32-bit 5-stage pipelined CPU",bg="#D9E2F3",fg="#555555",font=("Segoe UI",8)).pack(side=tk.LEFT,padx=(4,0))
        right=tk.Frame(frame,bg="#D9E2F3"); right.pack(side=tk.RIGHT,padx=8)
        self.status_dot=tk.Label(right,text="●",font=("Segoe UI",9),fg="#A00000",bg="#D9E2F3"); self.status_dot.pack(side=tk.LEFT,padx=(0,4))
        self.connection_label=tk.Label(right,textvariable=self.connection_var,bg="#D9E2F3",fg="#555555",font=("Segoe UI",8)); self.connection_label.pack(side=tk.LEFT)
    def create_serial_bar(self):
        toolbar=tk.Frame(self.root,bg="#D4D4D4",relief="raised",bd=1); toolbar.pack(fill=tk.X)
        row1=tk.Frame(toolbar,bg="#D4D4D4"); row1.pack(fill=tk.X,padx=4,pady=3)
        for text,cmd in [("New",self.new_file),("Open",self.open_file),("Save",self.save_file)]: ttk.Button(row1,text=text,style="Toolbar.TButton",command=cmd).pack(side=tk.LEFT,padx=1)
        ttk.Separator(row1,orient=tk.VERTICAL).pack(side=tk.LEFT,fill=tk.Y,padx=5,pady=1)
        self.run_button=ttk.Button(row1,text="Build / Sim",style="Primary.TButton",command=self.run_simulation); self.run_button.pack(side=tk.LEFT,padx=1)
        self.send_button=ttk.Button(row1,text="Send to FPGA",style="Primary.TButton",command=self.assemble_and_send); self.send_button.pack(side=tk.LEFT,padx=1)
        ttk.Button(row1,text="Assemble",style="Toolbar.TButton",command=self.assemble).pack(side=tk.LEFT,padx=1)
        ttk.Button(row1,text="Clear Output",style="Toolbar.TButton",command=self.clear_output).pack(side=tk.LEFT,padx=1)
        ttk.Separator(row1,orient=tk.VERTICAL).pack(side=tk.LEFT,fill=tk.Y,padx=5,pady=1)
        ttk.Label(row1,text="Target:",background="#D4D4D4",foreground="#333333").pack(side=tk.LEFT,padx=(2,4))
        ttk.Radiobutton(row1,text="Simulator",variable=self.mode_var,value="Simulation",command=self.mode_changed).pack(side=tk.LEFT,padx=2)
        ttk.Radiobutton(row1,text="Nexys A7",variable=self.mode_var,value="FPGA",command=self.mode_changed).pack(side=tk.LEFT,padx=2)
        ttk.Label(row1,textvariable=self.program_var,background="#D4D4D4",foreground="#666666").pack(side=tk.RIGHT,padx=8)
        row2=tk.Frame(toolbar,bg="#E7E7E7",relief="sunken",bd=1); row2.pack(fill=tk.X,padx=4,pady=(0,3))
        ttk.Label(row2,text="FPGA / UART",background="#E7E7E7",foreground="#333333",font=("Segoe UI",8,"bold")).pack(side=tk.LEFT,padx=(6,8))
        ttk.Label(row2,text="COM:",background="#E7E7E7",foreground="#555555").pack(side=tk.LEFT)
        self.port_combo=ttk.Combobox(row2,textvariable=self.port_var,width=10,state="readonly"); self.port_combo.pack(side=tk.LEFT,padx=4)
        ttk.Button(row2,text="Refresh",style="Toolbar.TButton",command=self.refresh_ports).pack(side=tk.LEFT,padx=(0,8))
        ttk.Label(row2,text="Baud:",background="#E7E7E7",foreground="#555555").pack(side=tk.LEFT)
        self.baud_combo=ttk.Combobox(row2,textvariable=self.baud_var,values=("921600","57600","38400","19200"),width=9,state="readonly"); self.baud_combo.pack(side=tk.LEFT,padx=4)
        self.connect_button=ttk.Button(row2,text="Connect",style="Toolbar.TButton",command=self.toggle_connection); self.connect_button.pack(side=tk.LEFT,padx=(0,10))
        ttk.Separator(row2,orient=tk.VERTICAL).pack(side=tk.LEFT,fill=tk.Y,padx=6,pady=2)
        ttk.Label(row2,text="Simulation:",background="#E7E7E7",foreground="#555555").pack(side=tk.LEFT,padx=(5,3))
        self.sim_command_entry=ttk.Entry(row2,textvariable=self.sim_command_var,width=24); self.sim_command_entry.pack(side=tk.LEFT,padx=3)
        ttk.Button(row2,text="Settings",style="Toolbar.TButton",command=self.show_simulation_settings).pack(side=tk.LEFT,padx=3)
        self.fpga_controls=row2
    def mode_changed(self):
        simulation = self.mode_var.get() == "Simulation"
        state = "disabled" if simulation else "normal"
        self.connect_button.config(state=state)
        self.port_combo.config(state="disabled" if simulation else "readonly")
        self.baud_combo.config(state="disabled" if simulation else "readonly")
        self.send_button.config(state="disabled" if simulation else "normal")
        self.run_button.config(state="normal" if simulation else "disabled")
        if simulation:
            self.status("Simulation mode selected")
            self.connection_var.set("Simulation mode")
            self.status_dot.config(fg=self.C["accent"])
        else:
            self.connection_var.set("Disconnected" if not (self.serial_port and self.serial_port.is_open)
                                     else self.connection_var.get())
            self.status_dot.config(
                fg=self.C["green"] if self.serial_port and self.serial_port.is_open else self.C["red"]
            )
            self.status("FPGA mode selected")

    def show_simulation_settings(self):
        win = tk.Toplevel(self.root)
        win.title("Simulation Settings")
        win.geometry("620x230")
        win.minsize(520, 210)
        win.configure(bg=self.C["bg"])

        frame = tk.Frame(win, bg=self.C["panel"], highlightbackground=self.C["border"], highlightthickness=1)
        frame.pack(fill=tk.BOTH, expand=True, padx=14, pady=14)

        tk.Label(frame, text="Simulation command", bg=self.C["panel"], fg=self.C["text"],
                 font=("Segoe UI Semibold", 10)).grid(row=0, column=0, sticky="w", padx=12, pady=(14, 5))
        cmd = ttk.Entry(frame, textvariable=self.sim_command_var, width=55)
        cmd.grid(row=0, column=1, padx=12, pady=(14, 5), sticky="ew")

        tk.Label(frame, text="Result JSON file", bg=self.C["panel"], fg=self.C["text"],
                 font=("Segoe UI Semibold", 10)).grid(row=1, column=0, sticky="w", padx=12, pady=5)
        res = ttk.Entry(frame, textvariable=self.sim_result_var, width=55)
        res.grid(row=1, column=1, padx=12, pady=5, sticky="ew")

        tk.Label(frame,
                 text="The simulation script should read program.hex and write the CPU result as JSON.",
                 bg=self.C["panel"], fg=self.C["muted"], wraplength=520, justify="left").grid(
                     row=2, column=0, columnspan=2, sticky="w", padx=12, pady=8)

        ttk.Button(frame, text="Close", command=win.destroy).grid(row=3, column=1, sticky="e", padx=12, pady=10)
        frame.grid_columnconfigure(1, weight=1)

    def write_hex_file(self, machine_code):
        base = os.path.dirname(self.current_file) if self.current_file else os.getcwd()
        path = os.path.join(base, "program.hex")
        with open(path, "w", encoding="ascii") as f:
            for word in machine_code:
                f.write(f"{word & 0xFFFFFFFF:08X}\n")
        return path

    def run_simulation(self):
        if self.mode_var.get() != "Simulation":
            return

        machine_code = self.assemble()
        if machine_code is None:
            return

        try:
            hex_path = self.write_hex_file(machine_code)
        except Exception as exc:
            messagebox.showerror("Simulation", f"Could not create program.hex:\n\n{exc}")
            return

        command = self.sim_command_var.get().strip()
        if not command:
            messagebox.showerror("Simulation", "Set a simulation command in Settings.")
            return

        result_path = self.sim_result_var.get().strip() or "simulation_result.json"
        result_full = os.path.join(os.path.dirname(hex_path), result_path)

        # Remove stale result so an old CPU result can never be displayed as a new one.
        try:
            if os.path.exists(result_full):
                os.remove(result_full)
        except OSError:
            pass

        self.cpu_status_var.set("SIMULATING")
        self.cpu_badge.config(bg="#dbeafe", fg="#1d4ed8")
        self.program_var.set(f"program.hex created • {len(machine_code)} words")
        self.status(f"Starting simulation using {os.path.basename(hex_path)}")

        def worker():
            try:
                cwd = os.path.dirname(hex_path) or os.getcwd()
                # If the command is a batch/script/executable path, run through the shell.
                proc = subprocess.Popen(
                    command,
                    cwd=cwd,
                    shell=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    universal_newlines=True
                )
                self.sim_process = proc
                try:
                    stdout, _ = proc.communicate(timeout=self.simulation_timeout)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    stdout, _ = proc.communicate()
                    self.rx_queue.put(("SIM_ERROR", f"Simulation timed out after {self.simulation_timeout} seconds.\n{stdout}"))
                    return

                if stdout:
                    self.rx_queue.put(("SIM_LOG", stdout))

                if proc.returncode != 0:
                    self.rx_queue.put(("SIM_ERROR", f"Simulation failed with exit code {proc.returncode}."))
                    return

                if not os.path.exists(result_full):
                    self.rx_queue.put((
                        "SIM_ERROR",
                        f"Simulation finished, but result file was not found:\n{result_full}"
                    ))
                    return

                with open(result_full, "r", encoding="utf-8") as f:
                    result = json.load(f)

                self.rx_queue.put(("SIM_RESULT", result))

            except Exception as exc:
                self.rx_queue.put(("SIM_ERROR", str(exc)))
            finally:
                self.sim_process = None

        self.sim_thread = threading.Thread(target=worker, daemon=True)
        self.sim_thread.start()

    def handle_simulation_result(self, result):
        """Parse and display the exact JSON emitted by the CPU simulator."""
        try:
            if not isinstance(result, dict):
                raise ValueError("Result JSON is not an object.")

            pc = int(str(result.get("pc", "0")).strip(), 0)
            halt = int(result.get("halt", 0))

            regs = result.get("registers")

            if not isinstance(regs, list):
                raise ValueError(
                    "Result JSON 'registers' field is missing or is not an array."
                )

            if len(regs) != 32:
                raise ValueError(
                    f"Result JSON contains {len(regs)} registers; expected 32."
                )

            registers = [
                int(str(value).strip(), 0) & 0xFFFFFFFF
                for value in regs
            ]

            # Update CPU status.
            self.pc_var.set(f"0x{pc:08X}")
            self.halt_var.set("HALTED" if halt else "0x00")
            self.cpu_status_var.set("HALTED" if halt else "RUNNING")

            self.cpu_badge.config(
                bg="#dcfce7" if halt else "#fef3c7",
                fg="#166534" if halt else "#92400e",
            )

            # Update the register table using the actual Treeview children.
            # This does not depend on the internal item names being R0, R1, etc.
            tree_items = self.reg_tree.get_children()

            if len(tree_items) != 32:
                raise ValueError(
                    f"Register table contains {len(tree_items)} rows; expected 32."
                )

            for i, value in enumerate(registers):
                signed = (
                    value
                    if value < 0x80000000
                    else value - 0x100000000
                )

                self.reg_tree.item(
                    tree_items[i],
                    values=(
                        f"R{i}",
                        f"0x{value:08X}",
                        str(signed),
                    ),
                )

            self.packet_count += 1
            self.packet_var.set(
                f"Simulation result #{self.packet_count} • "
                f"PC 0x{pc:08X} • "
                f"{'HALTED' if halt else 'RUNNING'}"
            )

            self.status("FRESH SIMULATION COMPLETED SUCCESSFULLY")

        except Exception as exc:
            self.cpu_status_var.set("ERROR")
            self.cpu_badge.config(
                bg="#fee2e2",
                fg="#991b1b",
            )
            self.status(f"Fresh simulation result error: {exc}")
            messagebox.showerror(
                "Fresh Simulation Result Error",
                str(exc),
            )

    def create_main_area(self):
        self.main_paned=tk.PanedWindow(self.root,orient=tk.HORIZONTAL,sashwidth=4,bg="#AFAFAF",bd=0,relief="flat"); self.main_paned.pack(fill=tk.BOTH,expand=True,padx=3,pady=3)
        project=tk.Frame(self.main_paned,bg="#F3F3F3",relief="sunken",bd=1,width=210); self.main_paned.add(project,minsize=170,width=210)
        ph=tk.Frame(project,bg="#D9D9D9",height=25,relief="raised",bd=1); ph.pack(fill=tk.X); ph.pack_propagate(False); tk.Label(ph,text="Project",bg="#D9D9D9",fg="#333333",font=("Segoe UI",8,"bold")).pack(side=tk.LEFT,padx=6)
        self.project_tree=ttk.Treeview(project,show="tree",selectmode="browse"); self.project_tree.pack(fill=tk.BOTH,expand=True,padx=2,pady=2)
        root_id=self.project_tree.insert("","end",text="CPU_Project",open=True); target_id=self.project_tree.insert(root_id,"end",text="Target 1",open=True); src_id=self.project_tree.insert(target_id,"end",text="Source Group 1",open=True)
        self.project_tree.insert(src_id,"end",text="program.asm"); self.project_tree.insert(src_id,"end",text="assembler.py"); self.project_tree.insert(target_id,"end",text="program.hex")
        fpga_id=self.project_tree.insert(root_id,"end",text="FPGA / Nexys A7",open=False); self.project_tree.insert(fpga_id,"end",text="UART 921600 8-N-1"); self.project_tree.bind("<Double-1>",self.project_tree_open)

        editor_panel=tk.Frame(self.main_paned,bg="#FFFFFF",relief="sunken",bd=1); self.main_paned.add(editor_panel,minsize=420)
        tab=tk.Frame(editor_panel,bg="#D9D9D9",height=27,relief="raised",bd=1); tab.pack(fill=tk.X); tab.pack_propagate(False)
        self.file_label=tk.Label(tab,textvariable=self.file_var,bg="#FFFFFF",fg="#17365D",font=("Segoe UI",8,"bold"),padx=10); self.file_label.pack(side=tk.LEFT,fill=tk.Y)
        tk.Label(tab,text="Assembly Source",bg="#D9D9D9",fg="#666666",font=("Segoe UI",8)).pack(side=tk.LEFT,padx=8)
        edit_area=tk.Frame(editor_panel,bg="#FFFFFF"); edit_area.pack(fill=tk.BOTH,expand=True)
        self.line_numbers=tk.Text(edit_area,width=5,padx=5,pady=7,takefocus=0,border=0,background="#F0F0F0",foreground="#777777",font=("Consolas",11),state="disabled",wrap=tk.NONE); self.line_numbers.pack(side=tk.LEFT,fill=tk.Y)
        self.editor=tk.Text(edit_area,wrap=tk.NONE,font=("Consolas",11),undo=True,padx=8,pady=7,border=0,background="#FFFFFF",foreground="#202020",insertbackground="#202020",selectbackground="#C7D7E7",selectforeground="#17365D"); self.editor.pack(side=tk.LEFT,fill=tk.BOTH,expand=True)
        sy=ttk.Scrollbar(edit_area,orient=tk.VERTICAL,command=self._editor_yview); sy.pack(side=tk.RIGHT,fill=tk.Y); sx=ttk.Scrollbar(edit_area,orient=tk.HORIZONTAL,command=self.editor.xview); sx.pack(side=tk.BOTTOM,fill=tk.X); self.editor.configure(yscrollcommand=lambda *a:self._sync_scrollbar(sy,*a),xscrollcommand=sx.set)
        self.editor.tag_configure("instruction",foreground="#0000A0",font=("Consolas",11,"bold")); self.editor.tag_configure("register",foreground="#008000"); self.editor.tag_configure("number",foreground="#804000"); self.editor.tag_configure("label",foreground="#800080",font=("Consolas",11,"bold")); self.editor.tag_configure("comment",foreground="#008000"); self.editor.tag_configure("error_line",background="#FFD6D6",foreground="#A00000")
        self.editor.bind("<KeyRelease>",self.editor_changed); self.editor.bind("<ButtonRelease-1>",lambda e:self.update_cursor_position()); self.editor.bind("<MouseWheel>",lambda e:self.update_line_numbers())

        monitor=tk.Frame(self.main_paned,bg="#F3F3F3",relief="sunken",bd=1,width=300); self.main_paned.add(monitor,minsize=260,width=300)
        mh=tk.Frame(monitor,bg="#D9D9D9",height=27,relief="raised",bd=1); mh.pack(fill=tk.X); mh.pack_propagate(False); tk.Label(mh,text="CPU Monitor",bg="#D9D9D9",fg="#333333",font=("Segoe UI",8,"bold")).pack(side=tk.LEFT,padx=6)
        self.cpu_badge=tk.Label(mh,textvariable=self.cpu_status_var,bg="#E8E8E8",fg="#666666",font=("Segoe UI",8,"bold"),padx=6); self.cpu_badge.pack(side=tk.RIGHT,padx=4,pady=3)
        info=tk.Frame(monitor,bg="#F3F3F3"); info.pack(fill=tk.X,padx=6,pady=6); self.make_info_card(info,"PC",self.pc_var,0); self.make_info_card(info,"HALT",self.halt_var,1)
        regs_frame=tk.Frame(monitor,bg="#FFFFFF",relief="sunken",bd=1); regs_frame.pack(fill=tk.BOTH,expand=True,padx=5,pady=(0,5))
        self.reg_tree=ttk.Treeview(regs_frame,columns=("register","hex","decimal"),show="headings",selectmode="browse"); self.reg_tree.heading("register",text="REG"); self.reg_tree.heading("hex",text="HEX"); self.reg_tree.heading("decimal",text="DEC"); self.reg_tree.column("register",width=48,anchor=tk.CENTER,stretch=False); self.reg_tree.column("hex",width=105,anchor=tk.CENTER); self.reg_tree.column("decimal",width=85,anchor=tk.E); self.reg_tree.pack(side=tk.LEFT,fill=tk.BOTH,expand=True)
        ry=ttk.Scrollbar(regs_frame,orient=tk.VERTICAL,command=self.reg_tree.yview); ry.pack(side=tk.RIGHT,fill=tk.Y); self.reg_tree.configure(yscrollcommand=ry.set)
        for i in range(32):
            self.reg_tree.insert(
                "",
                tk.END,
                iid=f"REG_{i}",
                values=(f"R{i}", "0x00000000", "0"),
            )

    def project_tree_open(self,event=None):
        item=self.project_tree.selection()
        if not item:return
        text=self.project_tree.item(item[0],"text")
        if text=="program.asm":self.status("Assembly source is open in the editor")
        elif text=="program.hex" and hasattr(self,"output_notebook"):self.output_notebook.select(self.machine_tab)
        elif text=="UART 921600 8-N-1":self.status("Nexys A7 UART target: 921600 baud, 8-N-1")
    def make_info_card(self,parent,title,variable,column):
        card=tk.Frame(parent,bg="#FFFFFF",highlightbackground="#BDBDBD",highlightthickness=1); card.grid(row=0,column=column,sticky="ew",padx=(0 if column==0 else 3,0)); parent.grid_columnconfigure(column,weight=1)
        tk.Label(card,text=title,bg="#FFFFFF",fg="#777777",font=("Segoe UI",7,"bold")).pack(anchor="w",padx=7,pady=(4,0)); tk.Label(card,textvariable=variable,bg="#FFFFFF",fg="#17365D",font=("Consolas",10,"bold")).pack(anchor="w",padx=7,pady=(0,5))

    def create_bottom_area(self):
        frame=tk.Frame(self.root,bg="#D9D9D9",relief="sunken",bd=1,height=190); frame.pack(fill=tk.X,padx=3,pady=(0,3)); frame.pack_propagate(False)
        self.output_notebook=ttk.Notebook(frame); self.output_notebook.pack(fill=tk.BOTH,expand=True)
        self.build_tab=tk.Frame(self.output_notebook,bg="#FFFFFF"); self.output_notebook.add(self.build_tab,text="Build Output")
        self.build_output=tk.Text(self.build_tab,font=("Consolas",9),background="#FFFFFF",foreground="#202020",border=0,wrap=tk.NONE); self.build_output.pack(fill=tk.BOTH,expand=True,padx=2,pady=2); self.build_output.insert("1.0", "Build Output\nReady.  F5 Assemble   F6 Send to FPGA   F7 Run Simulation\n"); self.build_output.config(state="disabled")
        machine_frame=tk.Frame(self.output_notebook,bg="#FFFFFF"); self.output_notebook.add(machine_frame,text="Machine Code"); self.machine_tab=machine_frame
        self.output=tk.Text(machine_frame,font=("Consolas",9),background="#FFFFFF",foreground="#004080",border=0,wrap=tk.NONE,state="disabled",padx=8,pady=5); self.output.pack(side=tk.LEFT,fill=tk.BOTH,expand=True); oy=ttk.Scrollbar(machine_frame,orient=tk.VERTICAL,command=self.output.yview); oy.pack(side=tk.RIGHT,fill=tk.Y); self.output.configure(yscrollcommand=oy.set)
        serial_frame=tk.Frame(self.output_notebook,bg="#FFFFFF"); self.output_notebook.add(serial_frame,text="Serial Monitor"); self.serial_output=tk.Text(serial_frame,font=("Consolas",9),background="#FFFFFF",foreground="#202020",border=0,wrap=tk.NONE); self.serial_output.pack(fill=tk.BOTH,expand=True,padx=2,pady=2)
        activity=tk.Frame(self.root,bg="#EEEEEE",relief="sunken",bd=1,height=22); activity.pack(fill=tk.X,padx=3); activity.pack_propagate(False); tk.Label(activity,text="Status:",bg="#EEEEEE",fg="#555555",font=("Segoe UI",8,"bold")).pack(side=tk.LEFT,padx=(7,3)); self.activity=tk.Label(activity,textvariable=self.packet_var,bg="#EEEEEE",fg="#555555",font=("Segoe UI",8)); self.activity.pack(side=tk.LEFT)
    def create_status_bar(self):
        bar=tk.Frame(self.root,bg="#D4D4D4",relief="sunken",bd=1,height=22); bar.pack(fill=tk.X,side=tk.BOTTOM); bar.pack_propagate(False)
        tk.Label(bar,textvariable=self.cursor_var,bg="#D4D4D4",fg="#444444",font=("Segoe UI",8)).pack(side=tk.LEFT,padx=8)
        tk.Label(bar,text="32-bit CPU  |  F5 Assemble  |  F6 Send to FPGA  |  F7 Simulation",bg="#D4D4D4",fg="#555555",font=("Segoe UI",8)).pack(side=tk.RIGHT,padx=8)
    def insert_default_program(self):
        source = """# 32-bit CPU test program
# ----------------------

MOVI R1, 100
MOVI R2, 123

SW R2, 0(R1)
LW R3, 0(R1)

ADDI R4, R3, 1
MOVI R5, 999

HLT
"""
        self.editor.insert("1.0", source)
        self.update_line_numbers()
        self.highlight_syntax()

    # =========================================================
    # EDITOR
    # =========================================================

    def editor_changed(self, event=None):
        self.update_line_numbers()
        self.highlight_syntax()
        self.update_cursor_position()

    def update_cursor_position(self):
        try:
            index = self.editor.index(tk.INSERT)
            line, col = index.split(".")
            self.cursor_var.set(f"Ln {line}, Col {int(col) + 1}")
        except Exception:
            pass

    def _editor_yview(self, *args):
        self.editor.yview(*args)
        self.line_numbers.yview_moveto(self.editor.yview()[0])

    def _sync_scrollbar(self, scrollbar, *args):
        scrollbar.set(*args)
        self.line_numbers.yview_moveto(self.editor.yview()[0])

    def update_line_numbers(self, event=None):
        try:
            count = int(self.editor.index("end-1c").split(".")[0])
            numbers = "\n".join(str(i) for i in range(1, count + 1))
            self.line_numbers.config(state="normal")
            self.line_numbers.delete("1.0", tk.END)
            self.line_numbers.insert("1.0", numbers)
            self.line_numbers.config(state="disabled")
        except Exception:
            pass

    def highlight_syntax(self):
        for tag in ("instruction", "register", "number", "label", "comment", "error_line"):
            self.editor.tag_remove(tag, "1.0", tk.END)

        source = self.editor.get("1.0", "end-1c")

        for line_no, line in enumerate(source.splitlines(), start=1):
            comment_pos = line.find("#")

            if comment_pos >= 0:
                self.editor.tag_add(
                    "comment",
                    f"{line_no}.{comment_pos}",
                    f"{line_no}.end",
                )
                code = line[:comment_pos]
            else:
                code = line

            label = re.search(r"\b[A-Za-z_][A-Za-z0-9_]*:", code)
            if label:
                self.editor.tag_add(
                    "label",
                    f"{line_no}.{label.start()}",
                    f"{line_no}.{label.end()}",
                )

            for mnemonic in self.INSTRUCTIONS:
                for match in re.finditer(
                    r"\b" + re.escape(mnemonic) + r"\b",
                    code,
                    re.IGNORECASE,
                ):
                    self.editor.tag_add(
                        "instruction",
                        f"{line_no}.{match.start()}",
                        f"{line_no}.{match.end()}",
                    )

            for match in re.finditer(
                r"\bR(?:[0-9]|[12][0-9]|3[01])\b",
                code,
                re.IGNORECASE,
            ):
                self.editor.tag_add(
                    "register",
                    f"{line_no}.{match.start()}",
                    f"{line_no}.{match.end()}",
                )

            for match in re.finditer(
                r"(?<![A-Za-z_])[-+]?(?:0[xX][0-9A-Fa-f]+|\d+)",
                code,
            ):
                self.editor.tag_add(
                    "number",
                    f"{line_no}.{match.start()}",
                    f"{line_no}.{match.end()}",
                )

    # =========================================================
    # FILES
    # =========================================================

    def new_file(self):
        self.editor.delete("1.0", tk.END)
        self.current_file = None
        self.file_var.set("Untitled.asm")
        self.clear_output()
        self.status("New file")
        self.update_line_numbers()
        self.highlight_syntax()

    def open_file(self):
        filename = filedialog.askopenfilename(
            title="Open Assembly File",
            filetypes=[
                ("Assembly files", "*.asm"),
                ("Text files", "*.txt"),
                ("All files", "*.*"),
            ],
        )

        if not filename:
            return

        try:
            with open(filename, "r", encoding="utf-8") as f:
                source = f.read()

            self.editor.delete("1.0", tk.END)
            self.editor.insert("1.0", source)

            self.current_file = filename
            self.file_var.set(os.path.basename(filename))
            self.update_line_numbers()
            self.highlight_syntax()
            self.status(f"Opened {os.path.basename(filename)}")

        except Exception as exc:
            messagebox.showerror("Open Error", str(exc))

    def save_file(self):
        if not self.current_file:
            return self.save_as()

        try:
            with open(self.current_file, "w", encoding="utf-8") as f:
                f.write(self.editor.get("1.0", "end-1c"))

            self.file_var.set(os.path.basename(self.current_file))
            self.status(f"Saved {os.path.basename(self.current_file)}")
            return True

        except Exception as exc:
            messagebox.showerror("Save Error", str(exc))
            return False

    def save_as(self):
        filename = filedialog.asksaveasfilename(
            title="Save Assembly File",
            defaultextension=".asm",
            filetypes=[
                ("Assembly files", "*.asm"),
                ("Text files", "*.txt"),
                ("All files", "*.*"),
            ],
        )

        if not filename:
            return False

        self.current_file = filename
        return self.save_file()

    # =========================================================
    # VALIDATION
    # =========================================================

    def validate_source(self, source):
        lines = source.splitlines()
        labels = set()

        # Pass 1: labels
        for line_no, original in enumerate(lines, start=1):
            line = original.split("#", 1)[0].strip()
            if not line:
                continue

            if ":" in line:
                label, _ = line.split(":", 1)
                label = label.strip()

                if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", label):
                    raise ValueError(f"Line {line_no}: Invalid label: {label}")

                if label.upper() in self.INSTRUCTIONS:
                    raise ValueError(
                        f"Line {line_no}: Label cannot use instruction name: {label}"
                    )

                if label.upper() in {x.upper() for x in labels}:
                    raise ValueError(f"Line {line_no}: Duplicate label: {label}")

                labels.add(label)

        operand_counts = {
            "MOVI": 2,
            "ADD": 3, "SUB": 3, "AND": 3, "OR": 3, "SLT": 3, "MUL": 3,
            "MOV": 2,
            "ADDI": 3, "SUBI": 3, "SLTI": 3,
            "LW": 2, "SW": 2,
            "BEQZ": 2, "BNEQZ": 2,
            "J": 1,
            "HLT": 0,
        }

        register_positions = {
            "MOVI": [0],
            "ADD": [0, 1, 2], "SUB": [0, 1, 2],
            "AND": [0, 1, 2], "OR": [0, 1, 2],
            "SLT": [0, 1, 2], "MUL": [0, 1, 2],
            "MOV": [0, 1],
            "ADDI": [0, 1], "SUBI": [0, 1], "SLTI": [0, 1],
            "LW": [0], "SW": [0],
            "BEQZ": [0], "BNEQZ": [0],
        }

        immediate_positions = {
            "MOVI": [1],
            "ADDI": [2], "SUBI": [2], "SLTI": [2],
        }

        for line_no, original in enumerate(lines, start=1):
            line = original.split("#", 1)[0].strip()
            if not line:
                continue

            if ":" in line:
                _, line = line.split(":", 1)
                line = line.strip()
                if not line:
                    continue

            parts = line.replace(",", " ").split()
            mnemonic = parts[0].upper()
            operands = parts[1:]

            if mnemonic not in self.INSTRUCTIONS:
                raise ValueError(f"Line {line_no}: Unknown instruction: {mnemonic}")

            expected = operand_counts[mnemonic]
            if len(operands) != expected:
                raise ValueError(
                    f"Line {line_no}: {mnemonic} requires {expected} operand"
                    f"{'s' if expected != 1 else ''}, got {len(operands)}"
                )

            for pos in register_positions.get(mnemonic, []):
                reg = operands[pos].upper()
                if not re.fullmatch(r"R[0-9]+", reg):
                    raise ValueError(f"Line {line_no}: Invalid register: {operands[pos]}")
                if int(reg[1:]) > 31:
                    raise ValueError(f"Line {line_no}: Register out of range: {reg}")

            for pos in immediate_positions.get(mnemonic, []):
                try:
                    value = int(operands[pos], 0)
                except ValueError:
                    raise ValueError(
                        f"Line {line_no}: Invalid immediate: {operands[pos]}"
                    )
                if not -32768 <= value <= 65535:
                    raise ValueError(
                        f"Line {line_no}: Immediate out of 16-bit range: {value}"
                    )

            if mnemonic in ("LW", "SW"):
                match = re.fullmatch(
                    r"([-+]?(?:0[xX][0-9A-Fa-f]+|\d+))\((R[0-9]+)\)",
                    operands[1],
                    re.IGNORECASE,
                )
                if not match:
                    raise ValueError(
                        f"Line {line_no}: Invalid memory syntax. "
                        f"Use {mnemonic} Rt, offset(Rs)"
                    )

                offset = int(match.group(1), 0)
                reg = int(match.group(2)[1:])
                if not -32768 <= offset <= 65535:
                    raise ValueError(
                        f"Line {line_no}: Memory offset out of 16-bit range"
                    )
                if reg > 31:
                    raise ValueError(f"Line {line_no}: Register out of range")

            if mnemonic in ("BEQZ", "BNEQZ", "J"):
                label = operands[-1]
                if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", label):
                    raise ValueError(f"Line {line_no}: Invalid label: {label}")
                if label not in labels:
                    raise ValueError(f"Line {line_no}: Undefined label: {label}")

    # =========================================================
    # ASSEMBLER
    # =========================================================

    def assemble(self, show_message=False):
        source = self.editor.get("1.0", "end-1c")

        if not source.strip():
            messagebox.showwarning("Assembler", "Assembly editor is empty.")
            return None

        self.editor.tag_remove("error_line", "1.0", tk.END)

        try:
            self.validate_source(source)
            machine_code = list(assemble_program(source))

            # FPGA loader needs FFFFFFFF as the end-of-program marker.
            if not machine_code or machine_code[-1] != 0xFFFFFFFF:
                machine_code.append(0xFFFFFFFF)

            self.machine_code = machine_code
            self.display_machine_code(machine_code)

            # Always create program.hex beside the assembly file (or in the
            # current working directory for an unsaved document).
            hex_path = self.write_hex_file(machine_code)

            self.program_var.set(
                f"{len(machine_code)} words  •  "
                f"{(len(machine_code) - 1) * 4} bytes + end marker"
            )
            self.status(f"Assembly successful • {len(machine_code)} words")

            if show_message:
                messagebox.showinfo(
                    "Assembly Successful",
                    f"Generated {len(machine_code)} words.",
                )

            return machine_code

        except ValueError as exc:
            self.show_assembly_error(exc)
            return None
        except Exception as exc:
            messagebox.showerror("Assembler Error", str(exc))
            self.status("Assembly failed")
            return None

    def display_machine_code(self, machine_code):
        self.output.config(state="normal")
        self.output.delete("1.0", tk.END)

        self.output.insert(
            tk.END,
            "ADDR     MACHINE CODE\n"
            "---------------------\n",
        )

        for address, word in enumerate(machine_code):
            self.output.insert(
                tk.END,
                f"0x{address * 4:04X}    {word:08X}\n",
            )

        self.output.config(state="disabled")

    def show_assembly_error(self, exc):
        self.output.config(state="normal")
        self.output.delete("1.0", tk.END)
        self.output.insert(
            "1.0",
            "ASSEMBLER ERROR\n"
            "================\n\n"
            f"{exc}",
        )
        self.output.config(state="disabled")

        match = re.search(r"Line (\d+):", str(exc))
        if match:
            line_no = int(match.group(1))
            self.editor.tag_add(
                "error_line",
                f"{line_no}.0",
                f"{line_no}.end",
            )
            self.editor.see(f"{line_no}.0")

        self.status("Assembly failed")

    # =========================================================
    # SERIAL
    # =========================================================

    def refresh_ports(self):
        if list_ports is None:
            self.port_combo["values"] = ()
            self.status("Install pyserial: pip install pyserial")
            return

        ports = [p.device for p in list_ports.comports()]
        self.port_combo["values"] = ports

        if ports:
            if self.port_var.get() not in ports:
                self.port_var.set(ports[0])
            self.status(f"{len(ports)} serial port(s) detected")
        else:
            self.port_var.set("")
            self.status("No serial ports detected")

    def toggle_connection(self):
        if self.serial_port and self.serial_port.is_open:
            self.disconnect_serial()
        else:
            self.connect_serial()

    def connect_serial(self):
        if serial is None:
            messagebox.showerror(
                "PySerial Required",
                "Install PySerial first:\n\npip install pyserial",
            )
            return

        port = self.port_var.get().strip()
        if not port:
            messagebox.showwarning("Serial", "Select a COM port first.")
            return

        try:
            baud = int(self.baud_var.get())

            self.serial_port = serial.Serial(
                port=port,
                baudrate=baud,
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE,
                timeout=0.1,
            )

            self.reader_stop.clear()
            self.reader_thread = threading.Thread(
                target=self.serial_reader,
                daemon=True,
            )
            self.reader_thread.start()

            self.connection_var.set(f"Connected • {port}")
            self.connect_button.config(text="Disconnect")
            self.status_dot.config(fg=self.C["green"])
            self.status("FPGA connected")

        except Exception as exc:
            self.serial_port = None
            messagebox.showerror("Serial Connection Error", str(exc))
            self.status("Connection failed")

    def disconnect_serial(self):
        self.reader_stop.set()

        try:
            if self.serial_port and self.serial_port.is_open:
                self.serial_port.close()
        except Exception:
            pass

        self.serial_port = None
        self.connection_var.set("Disconnected")
        self.connect_button.config(text="Connect")
        self.status_dot.config(fg=self.C["red"])
        self.status("FPGA disconnected")

    def serial_reader(self):
        while not self.reader_stop.is_set():
            try:
                ser = self.serial_port
                if ser is None or not ser.is_open:
                    break

                data = ser.read(256)
                if data:
                    self.rx_queue.put(bytes(data))

            except Exception as exc:
                self.rx_queue.put(("ERROR", str(exc)))
                break

    def process_rx_queue(self):
        try:
            while True:
                item = self.rx_queue.get_nowait()

                if isinstance(item, tuple):
                    kind = item[0]
                    if kind == "ERROR":
                        self.last_error = item[1]
                        self.status(f"UART error: {item[1]}")
                        continue
                    if kind == "SIM_ERROR":
                        self.cpu_status_var.set("ERROR")
                        self.cpu_badge.config(bg="#fee2e2", fg="#991b1b")
                        self.status("Simulation failed")
                        messagebox.showerror("Simulation Error", item[1])
                        continue
                    if kind == "SIM_LOG":
                        # Keep console output available in the Activity strip without
                        # overwhelming the GUI with the simulator's entire log.
                        lines = [x.strip() for x in item[1].splitlines() if x.strip()]
                        if lines:
                            self.status(f"XSim: {lines[-1][:180]}")
                        continue
                    if kind == "SIM_RESULT":
                        self.handle_simulation_result(item[1])
                        continue

                self.packet_buffer.extend(item)
                self.extract_packets()

        except queue.Empty:
            pass

        self.root.after(50, self.process_rx_queue)

    def extract_packets(self):
        PACKET_SIZE = 134

        while True:
            try:
                start = self.packet_buffer.index(0xAA)
            except ValueError:
                # Keep a small amount of data in case the header arrives
                # split across serial reads.
                self.packet_buffer.clear()
                return

            if start > 0:
                del self.packet_buffer[:start]

            if len(self.packet_buffer) < PACKET_SIZE:
                return

            packet = bytes(self.packet_buffer[:PACKET_SIZE])
            del self.packet_buffer[:PACKET_SIZE]

            self.handle_debug_packet(packet)

    # =========================================================
    # DEBUG PACKET
    # =========================================================

    def handle_debug_packet(self, packet):
        if len(packet) != 134 or packet[0] != 0xAA:
            return

        pc = int.from_bytes(packet[1:5], "big")

        registers = []
        for i in range(32):
            start = 5 + i * 4
            value = int.from_bytes(packet[start:start + 4], "big")
            registers.append(value)

        halt = packet[133]

        self.pc_var.set(f"0x{pc:08X}")
        self.halt_var.set(
            "HALTED" if halt == 1 else f"0x{halt:02X}"
        )

        if halt == 1:
            self.cpu_status_var.set("HALTED")
            self.cpu_badge.config(
                bg="#14532d",
                fg="#bbf7d0",
            )
        else:
            self.cpu_status_var.set("RUNNING")
            self.cpu_badge.config(
                bg="#713f12",
                fg="#fef3c7",
            )

        # Use the actual Treeview children rather than assuming IDs such as R0.
        tree_items = self.reg_tree.get_children()

        if len(tree_items) != 32:
            self.status(
                f"CPU monitor table error: found {len(tree_items)} rows, expected 32"
            )
            return

        for i, value in enumerate(registers):
            decimal = (
                value
                if value < 0x80000000
                else value - 0x100000000
            )

            self.reg_tree.item(
                tree_items[i],
                values=(
                    f"R{i}",
                    f"0x{value:08X}",
                    str(decimal),
                ),
            )

        self.packet_count += 1
        self.last_packet_time = time.time()

        self.packet_var.set(
            f"Packet #{self.packet_count} received  •  "
            f"PC 0x{pc:08X}  •  "
            f"{'HALTED' if halt == 1 else 'RUNNING'}"
        )

        self.status("CPU debug packet received")

    # =========================================================
    # SEND TO FPGA
    # =========================================================

    def assemble_and_send(self):
        if not self.serial_port or not self.serial_port.is_open:
            messagebox.showwarning(
                "FPGA Not Connected",
                "Connect to the FPGA UART before sending the program.",
            )
            return

        machine_code = self.assemble()
        if machine_code is None:
            return

        try:
            with self.serial_lock:
                # Flush stale data before programming.
                self.serial_port.reset_input_buffer()
                self.serial_port.reset_output_buffer()

                for index, word in enumerate(machine_code):
                    word &= 0xFFFFFFFF
                    data = word.to_bytes(4, byteorder="big")

                    self.serial_port.write(data)

                    self.status(
                        f"Sending word {index + 1}/{len(machine_code)}..."
                    )

                self.serial_port.flush()

            self.program_var.set(
                f"Sent {len(machine_code)} words to FPGA"
            )
            self.status("Program sent successfully")
            self.cpu_status_var.set("WAITING")
            self.cpu_badge.config(
                bg="#713f12",
                fg="#fef3c7",
            )

        except Exception as exc:
            messagebox.showerror("UART Send Error", str(exc))
            self.status("Program transmission failed")

    # =========================================================
    # MONITOR / OUTPUT
    # =========================================================

    def clear_monitor(self):
        self.packet_buffer.clear()
        self.packet_count = 0
        self.pc_var.set("0x00000000")
        self.halt_var.set("—")
        self.cpu_status_var.set("OFFLINE")
        self.cpu_badge.config(
            bg="#3f1d1d",
            fg="#991b1b",
        )

        tree_items = self.reg_tree.get_children()

        for i, item_id in enumerate(tree_items[:32]):
            self.reg_tree.item(
                item_id,
                values=(f"R{i}", "0x00000000", "0"),
            )

        self.packet_var.set("Monitor cleared")
        self.status("CPU monitor cleared")

    def clear_output(self):
        self.output.config(state="normal"); self.output.delete("1.0",tk.END); self.output.config(state="disabled")
        if hasattr(self,"build_output"):
            self.build_output.config(state="normal"); self.build_output.delete("1.0",tk.END); self.build_output.insert("1.0","Build Output\n"); self.build_output.config(state="disabled")
        self.status("Output cleared")

    def clear_activity(self):
        self.packet_var.set("No packet received")
        self.status("Activity cleared")

    def show_serial_log(self):
        win = tk.Toplevel(self.root)
        win.title("Serial Monitor")
        win.geometry("700x450")
        win.minsize(500, 300)
        win.configure(bg=self.C["bg"])

        text = tk.Text(
            win,
            background=self.C["editor"],
            foreground=self.C["text"],
            font=("Consolas", 10),
            border=0,
            padx=10,
            pady=10,
        )
        text.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)

        text.insert(
            tk.END,
            "Serial monitor\n\n"
            "The CPU monitor decodes the binary 134-byte debug packets "
            "automatically.\n\n"
            "Packet format:\n"
            "AA | PC(4) | R0..R31(128) | HALT(1)\n",
        )
        text.config(state="disabled")

    # =========================================================
    # REFERENCE / ABOUT
    # =========================================================

    def show_instruction_reference(self):
        window = tk.Toplevel(self.root)
        window.title("CPU Instruction Set")
        window.geometry("700x650")
        window.minsize(500, 400)
        window.configure(bg=self.C["bg"])

        frame = tk.Frame(window, bg=self.C["panel"])
        frame.pack(fill=tk.BOTH, expand=True, padx=12, pady=12)

        text = tk.Text(
            frame,
            font=("Consolas", 11),
            background=self.C["editor"],
            foreground=self.C["text"],
            insertbackground="white",
            border=0,
            padx=12,
            pady=12,
        )
        text.pack(fill=tk.BOTH, expand=True)

        text.insert(tk.END, "32-BIT CPU INSTRUCTION SET\n")
        text.insert(tk.END, "===========================\n\n")

        for instruction, syntax in self.INSTRUCTIONS.items():
            text.insert(tk.END, f"{instruction:<8} {syntax}\n")

        text.insert(
            tk.END,
            "\nRegisters: R0-R31\n"
            "Comments: # comment\n\n"
            "Example:\n"
            "MOVI R1, 10\n"
            "MOVI R2, 20\n"
            "ADD R3, R1, R2\n"
            "LOOP:\n"
            "SUBI R1, R1, 1\n"
            "BNEQZ R1, LOOP\n"
            "HLT\n",
        )

        text.config(state="disabled")

    def show_about(self):
        messagebox.showinfo(
            "About",
            "32-bit CPU Assembler IDE\n\n"
            "Assembly editor + assembler + simulation + FPGA UART monitor.\n\n"
            "UART: 921600 baud, 8-N-1\n"
            "Debug packet: 134 bytes",
        )

    # =========================================================
    # STATUS
    # =========================================================

    def status(self, text):
        self.packet_var.set(text)
        if hasattr(self,"build_output"):
            try:
                self.build_output.config(state="normal"); self.build_output.insert(tk.END,text+"\n"); self.build_output.see(tk.END); self.build_output.config(state="disabled")
            except tk.TclError: pass

    # =========================================================
    # SHORTCUTS
    # =========================================================

    def bind_shortcuts(self):
        self.root.bind("<Control-n>", lambda e: self.new_file())
        self.root.bind("<Control-o>", lambda e: self.open_file())
        self.root.bind("<Control-s>", lambda e: self.save_file())
        self.root.bind("<F5>", lambda e: self.assemble())
        self.root.bind("<F6>", lambda e: self.assemble_and_send())
        self.root.bind("<F7>", lambda e: self.run_simulation())

    # =========================================================
    # CLOSE
    # =========================================================

    def close_app(self):
        self.disconnect_serial()
        self.root.destroy()


if __name__ == "__main__":
    root = tk.Tk()
    app = CPUAssemblerIDE(root)
    root.mainloop()
