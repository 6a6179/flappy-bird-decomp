// Seed true ARM/Thumb entry points or export C-like output for each linker entry.
// @category FlappyBird
import ghidra.app.cmd.disassemble.DisassembleCommand;
import ghidra.app.decompiler.*;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.*;
import ghidra.program.model.lang.Register;
import ghidra.program.model.lang.RegisterValue;
import ghidra.program.model.listing.*;
import ghidra.program.model.symbol.SourceType;
import java.io.*;
import java.math.BigInteger;
import java.nio.file.*;
import java.util.*;

public class RecoverFunctions extends GhidraScript {
    record Entry(long start, long end, int mode, String name) {}

    public void run() throws Exception {
        String[] args = getScriptArgs();
        List<Entry> entries = new ArrayList<>();
        for (String line : Files.readAllLines(Path.of(args[1]))) {
            String[] field = line.split("\t", -1);
            entries.add(new Entry(Long.parseLong(field[0], 16), Long.parseLong(field[1], 16),
                                  Integer.parseInt(field[2]), field[3]));
        }
        if (args[0].equals("seed")) {
            seed(entries);
            Files.createFile(Path.of(args[1] + ".seeded"));
        } else if (args[0].equals("export")) {
            if (!Files.exists(Path.of(args[1] + ".seeded"))) throw new IOException("Seed step failed");
            export(entries, Path.of(args[2]));
        } else {
            throw new IllegalArgumentException("Expected seed or export");
        }
    }

    private void seed(List<Entry> entries) throws Exception {
        Register mode = currentProgram.getProgramContext().getRegister("TMode");
        Listing listing = currentProgram.getListing();
        Address first = toAddr(entries.get(0).start);
        Address last = toAddr(entries.get(entries.size()-1).end - 1);
        // The loader creates some functions at odd (Thumb-tagged) addresses.
        // Remove those overlapping namespaces before building clean, even-address entries.
        FunctionManager manager = currentProgram.getFunctionManager();
        List<Address> oldEntries = new ArrayList<>();
        for (Function f : manager.getFunctions(new AddressSet(first, last), true)) {
            oldEntries.add(f.getEntryPoint());
        }
        for (Address old : oldEntries) manager.removeFunction(old);
        listing.clearCodeUnits(first, last, true);
        for (Entry entry : entries) {
            monitor.checkCancelled();
            Address start = toAddr(entry.start);
            Address end = toAddr(entry.end - 1);
            BigInteger value = BigInteger.valueOf(entry.mode);
            currentProgram.getProgramContext().setValue(mode, start, end, value);
            DisassembleCommand cmd = new DisassembleCommand(start, new AddressSet(start, end), true);
            cmd.setInitialContext(new RegisterValue(mode, value));
            cmd.enableCodeAnalysis(false);
            cmd.applyTo(currentProgram, monitor);
            AddressSet body = cmd.getDisassembledAddressSet();
            if (body == null || !body.contains(start)) {
                throw new IOException("Failed to decode linker entry at " + start);
            }
            if (getFunctionAt(start) == null) {
                listing.createFunction(null, start, body, SourceType.ANALYSIS);
            }
        }
        println("Seeded " + entries.size() + " Mach-O function starts.");
    }

    private void export(List<Entry> entries, Path out) throws Exception {
        Register mode = currentProgram.getProgramContext().getRegister("TMode");
        DecompInterface iface = new DecompInterface();
        DecompileOptions options = new DecompileOptions();
        options.grabFromProgram(currentProgram);
        iface.setOptions(options);
        if (!iface.openProgram(currentProgram)) throw new IOException(iface.getLastMessage());
        Map<String, BufferedWriter> groups = new HashMap<>();
        int complete = 0;
        try (BufferedWriter index = Files.newBufferedWriter(out.resolve("index.tsv"))) {
            index.write("address\tnext_boundary\tmode\tobjc_method\tlisting\tstatus\n");
            for (Entry entry : entries) {
                monitor.checkCancelled();
                Address start = toAddr(entry.start);
                String file = String.format("text_%08x.c", entry.start & ~0xffffL);
                BufferedWriter group = groups.get(file);
                if (group == null) {
                    group = Files.newBufferedWriter(out.resolve(file));
                    group.write("/* Generated Ghidra pseudocode. Types, parameters and control flow are inferred. */\n");
                    groups.put(file, group);
                }
                Function f = getFunctionAt(start);
                BigInteger actual = currentProgram.getProgramContext().getValue(mode, start, false);
                String status;
                String code = "";
                if (actual == null || actual.intValue() != entry.mode) {
                    status = "instruction mode mismatch";
                } else if (f == null) {
                    status = "missing function";
                } else {
                    DecompileResults res = iface.decompileFunction(f, 120, monitor);
                    if (res.decompileCompleted() && res.getDecompiledFunction() != null) {
                        code = res.getDecompiledFunction().getC().stripTrailing() + "\n";
                        status = code.contains("WARNING:") ? "emitted with warning" : "emitted";
                        complete++;
                    } else {
                        status = "failed: " + res.getErrorMessage().replaceAll("\\s+", " ").trim();
                    }
                }
                String isa = entry.mode == 1 ? "Thumb" : "ARM";
                group.write(String.format("\n/* 0x%08x  %s  %s */\n", entry.start, isa, entry.name));
                if (code.isEmpty()) group.write("/* " + status + " */\n");
                else group.write(code);
                index.write(String.format("0x%08x\t0x%08x\t%s\t%s\t%s\t%s\n",
                    entry.start, entry.end, isa, entry.name, file, status));
            }
        } finally {
            iface.dispose();
            for (BufferedWriter writer : groups.values()) writer.close();
        }
        println("Emitted C-like output for " + complete + " of " + entries.size() + " entries.");
    }
}
