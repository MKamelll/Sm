module vm.machine;

import std.conv;
import std.stdio;
import std.range;
import std.variant;
import std.algorithm;
import std.array;

import vm.instruction;
import vm.error;
import vm.program;

alias Stack = Variant[];

class Machine
{
    Instruction[] mInstructions;
    const MAX_CAPACITY = 100;
    Stack mStack;
    Stack mCallStack;
    Instruction mCurrInstruction;
    Variant[string] mGlobals;
    int[string] mLabels;
    int mIp;
    int mSp;
    bool mHalt;

    this (Program program) {
        mInstructions = program.getInstructions();
        mStack = [];
        mCallStack = [];
        mIp = 0;
        mSp = -1;
        mHalt = false;
    }

    bool isAtEnd() {
        if (!mHalt && mIp < mInstructions.length) {
            return false;
        }

        return true;
    }

    Variant pop() {
        if (mSp < 0) {
            throw new VmError("Not enough operands on the stack for instruction '"
                ~ to!string(mCurrInstruction.getOpcode()) ~ "'");
        }

        Variant elm = mStack[mSp--];
        mStack.popBack();

        return elm;
    }

    T pop(T)() {
        if (mSp < 0) {
            throw new VmError("Not enough operands on the stack for instruction '"
                ~ to!string(mCurrInstruction.getOpcode()) ~ "'");
        }

        Variant elm = mStack[mSp--];
        mStack.popBack();

        if (elm.peek!T) return elm.get!T; 
        
        throw new VmError("For opcode '" ~ to!string(mCurrInstruction.mOpcode)
            ~ "' expected type '" ~ to!string(typeid(T)) ~ "' instead got '" ~ to!string(elm.type) ~ "'");
    }

    void push(Variant value) {
        mSp++;
        if (mSp > MAX_CAPACITY) throw new VmError("Stack overflow");
        mStack ~= value;
    }

    void push(T)(string value) {
        mSp++;
        if (mSp > MAX_CAPACITY) throw new VmError("Stack overflow");

        try {
            mStack ~= Variant(to!T(value));
        } catch (Exception err) {
             throw new VmError("Opcode '" ~ to!string(mCurrInstruction.mOpcode) ~  ", Invalid operand: " ~ err.msg);
        }
    }

    void push(T)(T value) {
        mSp++;
        if (mSp > MAX_CAPACITY) throw new VmError("Stack overflow");

        try {
            mStack ~= Variant(to!T(value));
        } catch (Exception err) {
            throw new VmError("Opcode '" ~ to!string(mCurrInstruction.mOpcode) ~  ", Invalid operand: " ~ err.msg);
        }
    }

    Instruction advance() {
        mCurrInstruction = mInstructions[mIp++];
        return mCurrInstruction;
    }

    // random stack access
    T stackGetAt(T) (int index) {
        Variant elm = mStack[index];

        if (elm.peek!T) return elm.get!T;

        throw new VmError("For opcode '" ~ to!string(mCurrInstruction.mOpcode)
            ~ "' expected type '" ~ to!string(typeid(T)) ~ "' instead got '" ~ to!string(elm.type) ~ "'");
    }

    void stackSetAt(T) (int index, T newVal) {
        try {
            mStack[index] = Variant(to!T(newVal));
        }  catch (Exception err) {
            throw new VmError("Opcode '" ~ to!string(mCurrInstruction.mOpcode) ~  ", Invalid operand: " ~ err.msg);
        }
    }

    // query globals
    bool globalsContains(string query) {
        Variant * value = (query in mGlobals);
        if (value !is null) return true;
        return false;
    }

    void globalsAppend(T)(string key, T value) {
        mGlobals[key] = Variant(value);
    }

    void globalsAppend(string key, Variant value) {
        mGlobals[key] = value;
    }

    T globalsGet(T)(string key) {
        if (globalsContains(key)) {
            if (mGlobals[key].peek!T) return mGlobals[key].get!T;

            throw new VmError("Expected global variable of type '" ~ to!string(typeid(T))
                ~ "' instead available type '" ~ to!string(mGlobals[key].type) ~ "'");
        }

        throw new VmError("Undefined global variable '" ~ key ~ "'");
    }

    Variant globalsGet(string key) {
        if (globalsContains(key)) return mGlobals[key];

        throw new VmError("Undefined global variable '" ~ key ~ "'");
    }

    // query labels
    bool labelsContains(string query) {
        int * value = (query in mLabels);
        if (value !is null) return true;
        return false;
    }

    void labelsAppend(string key, int value) {
        mLabels[key] = value;
    }

    int labelsGet(string key) {
        if (labelsContains(key)) return mLabels[key];

        throw new VmError("Undefined global variable '" ~ key ~ "'");
    }

    /* ___________________________________________________________________________________________________________ */
    
    Variant[] run() {

        while (!isAtEnd()) {
            Instruction curr = advance();
            switch (curr.getOpcode()) {

                // int
                case Opcode.PUSHI: pushInt(); break;
                case Opcode.ADDI: addInt(); break;
                case Opcode.MULI: mulInt(); break;
                case Opcode.DIVI: divInt(); break;
                case Opcode.SUBI: subInt(); break;
                
                // long
                case Opcode.PUSHL: pushLong(); break;
                case Opcode.ADDL: addLong(); break;
                case Opcode.MULL: mulLong(); break;
                case Opcode.DIVL: divLong(); break;
                case Opcode.SUBL: subLong(); break;

                // float
                case Opcode.PUSHF: pushFloat(); break;
                case Opcode.ADDF: addFloat(); break;
                case Opcode.MULF: mulFloat(); break;
                case Opcode.DIVF: divFloat(); break;
                case Opcode.SUBF: subFloat(); break;

                // bool
                case Opcode.PUSHB: pushBool(); break;
                
                // jmp
                case Opcode.JMP: jump(); break;
                case Opcode.JE: jumpIfEqual(); break;
                case Opcode.JG: jumpIfGreater(); break;
                case Opcode.JL: jumpIfLess(); break;
                case Opcode.JGE: jumpIfGreaterOrEqual(); break;
                case Opcode.JLE: jumpIfLessOrEqual(); break;

                // cmp
                case Opcode.CMPI: compareInt(); break;
                case Opcode.CMPF: compareFloat(); break;
                case Opcode.CMPL: compareLong(); break;

                // dec
                case Opcode.DECI: decrementInt(); break;
                case Opcode.DECF: decrementFloat(); break;
                case Opcode.DECL: decrementLong(); break;

                // loadg, storeg
                case Opcode.LOADG: loadGlobal(); break;
                case Opcode.STOREG: storeGlobal(); break;

                // label
                case Opcode.LABEL: label(); break;
                
                // halt
                case Opcode.HALT: halt(); break;
                default: throw new VmError("Unkown Machine Instruction: '" ~ to!string(curr.getOpcode()) ~ "'");
            }
            debugPrint();
        }
        
        return mStack;
    }

    // Int
    void pushInt() {
        push!int(mCurrInstruction.getOperand!int);
    }

    void addInt() {
        int firstOperand = pop!int;
        int secondOperand = pop!int;
        push!int(firstOperand + secondOperand);
    }

    void mulInt() {
        int firstOperand = pop!int;
        int secondOperand = pop!int;
        push!int(firstOperand * secondOperand);
    }

    void divInt() {
        int firstOperand = pop!int;
        int secondOperand = pop!int;
        push!int(secondOperand / firstOperand);
    }

    void subInt() {
        int firstOperand = pop!int;
        int secondOperand = pop!int;
        push!int(secondOperand - firstOperand);
    }
    
    // Long
    void pushLong() {
        push!long(mCurrInstruction.getOperand!long);
    }

    void addLong() {
        long firstOperand = pop!long;
        long secondOperand = pop!long;
        push!long(firstOperand + secondOperand);
    }

    void mulLong() {
        long firstOperand = pop!long;
        long secondOperand = pop!long;
        push!long(firstOperand * secondOperand);
    }

    void divLong() {
        long firstOperand = pop!long;
        long secondOperand = pop!long;
        push!long(secondOperand / firstOperand);
    }

    void subLong() {
        long firstOperand = pop!long;
        long secondOperand = pop!long;
        push!long(secondOperand - firstOperand);
    }

    // Float
    void pushFloat() {
        push!float(mCurrInstruction.getOperand!float);
    }

    void addFloat() {
        float firstOperand = pop!float;
        float secondOperand = pop!float;
        push!float(firstOperand + secondOperand);
    }

    void mulFloat() {
        float firstOperand = pop!float;
        float secondOperand = pop!float;
        push!float(firstOperand * secondOperand);
    }

    void divFloat() {
        float firstOperand = pop!float;
        float secondOperand = pop!float;
        push!float(secondOperand / firstOperand);
    }

    void subFloat() {
        float firstOperand = pop!float;
        float secondOperand = pop!float;
        push!float(secondOperand - firstOperand);
    }

    // bool
    void pushBool() {
        push!bool(mCurrInstruction.getOperand!bool);
    }

    // jmp
    void jump() {
        if (mCurrInstruction.peekOperand!string) {
            string labelName = mCurrInstruction.getOperand!string;
            Variant * value = (labelName in mGlobals);
            if (value is null) throw new VmError("Undefined label '" ~ labelName ~ "'");
            mIp = mGlobals[labelName].get!int;
        } else {
            int destination = mCurrInstruction.getOperand!int;
            mIp = destination;
        }
    }

    void jumpIfEqual() {
        int operand = pop!int;

        if (operand == 0) {
            int destinarion = mCurrInstruction.getOperand!int;
            mIp = destinarion;
        }
    }

    void jumpIfGreater() {
        int operand = pop!int;

        if (operand > 0) {
            int destinarion = mCurrInstruction.getOperand!int;
            mIp = destinarion;
        }
    }

    void jumpIfLess() {
        int operand = pop!int;

        if (operand < 0) {
            int destinarion = mCurrInstruction.getOperand!int;
            mIp = destinarion;
        }
    }

    void jumpIfGreaterOrEqual() {
        int operand = pop!int;

        if (operand == 0 || operand > 0) {
            int destinarion = mCurrInstruction.getOperand!int;
            mIp = destinarion;
        }
    }

    void jumpIfLessOrEqual() {
        int operand = pop!int;

        if (operand == 0 || operand < 0) {
            int destinarion = mCurrInstruction.getOperand!int;
            mIp = destinarion;
        }
    }

    // cmp
    void compareInt() {
        int firstOperand = pop!int;
        int secondOperand = pop!int;

        if (secondOperand == firstOperand) {
            push!int(0);
        } else if (secondOperand > firstOperand) {
            push!int(1);
        } else if (secondOperand < firstOperand) {
            push!int(-1);
        }
    }

    void compareFloat() {
        float firstOperand = pop!float;
        float secondOperand = pop!float;

        if (secondOperand == firstOperand) {
            push!int(0);
        } else if (secondOperand > firstOperand) {
            push!int(1);
        } else if (secondOperand < firstOperand) {
            push!int(-1);
        }
    }

    void compareLong() {
        long firstOperand = pop!long;
        long secondOperand = pop!long;

        if (secondOperand == firstOperand) {
            push!int(0);
        } else if (secondOperand > firstOperand) {
            push!int(1);
        } else if (secondOperand < firstOperand) {
            push!int(-1);
        }
    }

    // dec
    void decrementInt() {
        int value = pop!int;
        --value;
        push!int(value);
    }

    void decrementFloat() {
        float value = pop!float;
        --value;
        push!float(value);
    }
    
    void decrementLong() {
        long value = pop!long;
        --value;
        push!long(value);
    }

    // loadg
    void loadGlobal() {
        string var = mCurrInstruction.getOperand!string;
        push(globalsGet(var));
    }

    // storeg
    void storeGlobal() {
        Variant value = pop();
        string var = mCurrInstruction.getOperand!string;
        globalsAppend(var, value);
    }

    // label
    void label() {
        string labelName = mCurrInstruction.getOperand!string;
        
        if (labelsContains(labelName)) throw new VmError("There's a label already defined with the same name");

        labelsAppend(labelName, mIp);
    }

    // halt
    void halt() {
        mHalt = true;
    }

    void debugPrint() {
        writeln("Stack => " ~ to!string(mStack) ~ ", currInst: " ~ mCurrInstruction.toString());
    }
}
