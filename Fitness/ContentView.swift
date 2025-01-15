import SwiftUI
import Charts

// MARK: - Models
struct Workout: Identifiable, Codable {
    var id = UUID()
    var name: String
    var date: Date
    var exercises: [Exercise]
}

struct Exercise: Identifiable, Codable {
    var id = UUID()
    var name: String
    var history: [ExerciseLog] // Stores the history of each exercise.
}

struct ExerciseLog: Identifiable, Codable {
    var id = UUID()
    var date: Date // Date and time the log was created.
    var sets: Int
    var reps: Int
    var weight: Double
}

// MARK: - ViewModel
class WorkoutViewModel: ObservableObject {
    @Published var workouts: [Workout] = [] { // list of all workouts
        didSet {
            saveWorkouts() // runs the save workout funct. whenever the list changes
        }
    }
    
    // adds a entry to a specific exercise in a specified workout
    func addLog(to exercise: Exercise, in workout: Workout, sets: Int, reps: Int, weight: Double) {
        if let workoutIndex = workouts.firstIndex(where: { $0.id == workout.id }),
           let exerciseIndex = workouts[workoutIndex].exercises.firstIndex(where: { $0.id == exercise.id }) {
            let newLog = ExerciseLog(date: Date(), sets: sets, reps: reps, weight: weight)
            workouts[workoutIndex].exercises[exerciseIndex].history.append(newLog)
        }
    }

    private let fileName = "workouts.json"

    init() {
        loadWorkouts()
    }
    
    // adds a new workout
    func addWorkout(name: String) {
        let newWorkout = Workout(name: name, date: Date(), exercises: [])
        workouts.append(newWorkout)
    }

    // adds a new exercise to a workout or it will add it to an exisiting exercise
    func addExercise(to workout: Workout, name: String, sets: Int, reps: Int, weight: Double) {
        if let index = workouts.firstIndex(where: { $0.id == workout.id }) {
            let newLog = ExerciseLog(date: Date(), sets: sets, reps: reps, weight: weight)
            if let exerciseIndex = workouts[index].exercises.firstIndex(where: { $0.name == name }) {
                workouts[index].exercises[exerciseIndex].history.append(newLog)
            } else {
                let newExercise = Exercise(name: name, history: [newLog])
                workouts[index].exercises.append(newExercise)
            }
        }
    }

    // func. to save workouts to the JSON file
    private func saveWorkouts() {
        do {
            let url = getFileURL()
            let data = try JSONEncoder().encode(workouts)
            try data.write(to: url)
        } catch {
            print("Error saving workouts: \(error)")
        }
    }

    // loads workouts from the JSON file
    private func loadWorkouts() {
        do {
            let url = getFileURL()
            let data = try Data(contentsOf: url)
            let decodedWorkouts = try JSONDecoder().decode([Workout].self, from: data)
            workouts = decodedWorkouts
        } catch {
            print("Error loading workouts: \(error)")
        }
    }

    // gets the file URL
    private func getFileURL() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent(fileName)
    }
}

// MARK: - Views
struct AddWorkoutView: View {
    @Environment(\.dismiss) var dismiss
    @State private var workoutName = ""
    @ObservedObject var viewModel: WorkoutViewModel

    var body: some View {
        NavigationView {
            Form {
                TextField("Workout Name", text: $workoutName) // workout name input field
            }
            .navigationTitle("Add Workout")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if !workoutName.isEmpty {
                            viewModel.addWorkout(name: workoutName) // save the new workout
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AddExerciseView: View {
    @Environment(\.dismiss) var dismiss
    @State private var exerciseName = ""
    var workout: Workout
    @ObservedObject var viewModel: WorkoutViewModel

    var body: some View {
        NavigationView {
            Form {
                TextField("Exercise Name", text: $exerciseName) // exercise name input field
                    .autocapitalization(.words)
            }
            .navigationTitle("Add Exercise")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if !exerciseName.isEmpty {
                            let newExercise = Exercise(name: exerciseName, history: [])
                            if let index = viewModel.workouts.firstIndex(where: { $0.id == workout.id }) {
                                viewModel.workouts[index].exercises.append(newExercise) // add the new exercise
                            }
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct WorkoutDetailView: View {
    var workout: Workout
    @ObservedObject var viewModel: WorkoutViewModel
    @State private var showingAddExercise = false

    var body: some View {
        List {
            ForEach(workout.exercises) { exercise in
                NavigationLink(destination: ExerciseDetailView(workout: workout, exercise: exercise, viewModel: viewModel)) {
                    Text(exercise.name)
                        .font(.headline)
                }
            }
            .onDelete(perform: deleteExercise) // ability to delete exercise
        }
        .navigationTitle(workout.name)
        .toolbar {
            Button(action: {
                showingAddExercise = true
            }) {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseView(workout: workout, viewModel: viewModel)
        }
    }
    // delete exercise from the workout
        private func deleteExercise(at offsets: IndexSet) {
            if let index = viewModel.workouts.firstIndex(where: { $0.id == workout.id }) {
                viewModel.workouts[index].exercises.remove(atOffsets: offsets)
            }
        }
    }

struct ExerciseDetailView: View {
    var workout: Workout
    var exercise: Exercise
    @ObservedObject var viewModel: WorkoutViewModel
    @State private var sets = ""
    @State private var reps = ""
    @State private var weight = ""

    var body: some View {
        VStack {
            List {
                ForEach(exercise.history) { log in
                    HStack {
                        Text("\(log.date, formatter: dateFormatter)")
                        Spacer()
                        Text("\(log.sets)x\(log.reps) @ \(log.weight, specifier: "%.1f") lbs")
                    }
                }
            }

            Form {
                Section(header: Text("Add Log")) {
                    TextField("Sets", text: $sets)
                        .keyboardType(.numberPad)
                    TextField("Reps", text: $reps)
                        .keyboardType(.numberPad)
                    TextField("Weight (lbs)", text: $weight)
                        .keyboardType(.decimalPad)
                }
            }

            Button("Add Log") {
                if let setsInt = Int(sets),
                   let repsInt = Int(reps),
                   let weightDouble = Double(weight) {
                    // Add log data to the exercise
                    viewModel.addLog(to: exercise, in: workout, sets: setsInt, reps: repsInt, weight: weightDouble)
                    
                    // Reset text fields after adding log
                    sets = ""
                    reps = ""
                    weight = ""
                }
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .navigationTitle(exercise.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: ExerciseChartView(exercise: exercise)) {
                    Label("Chart", systemImage: "chart.bar.xaxis") // System chart icon
                        .font(.headline)
                        .foregroundColor(.blue)
                        .padding(8)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .shadow(radius: 5)
                }
            }
        }
    }
}



struct ExerciseChartView: View {
    var exercise: Exercise

    var body: some View {
        VStack {
            Text("History for \(exercise.name)") // title for chart exercise
                .font(.title)
                .padding()

            Chart {
                ForEach(exercise.history) { log in
                    LineMark(
                        x: .value("Date", log.date), // x axis
                        y: .value("Weight", log.weight) // y axis
                    )
                }
            }
            .frame(height: 300)
            .padding()
        }
        .navigationTitle("Exercise Chart")
    }
}


struct ContentView: View {
    @StateObject private var viewModel = WorkoutViewModel()
    @State private var showingAddWorkout = false

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.workouts) { workout in
                    NavigationLink(destination: WorkoutDetailView(workout: workout, viewModel: viewModel)) {
                        Text(workout.name)
                            .font(.headline)
                    }
                }
                .onDelete(perform: deleteWorkout) // ability to delete workouts
            }
            .navigationTitle("Workouts")
            .toolbar {
                Button(action: {
                    showingAddWorkout = true
                }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingAddWorkout) {
                AddWorkoutView(viewModel: viewModel)
            }
        }
    }
    
    // deletes workout from list
    private func deleteWorkout(at offsets: IndexSet) {
            viewModel.workouts.remove(atOffsets: offsets)
        }
    }

// MARK: - Date Formatter
let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

// MARK: - Main App
@main
struct WorkoutApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/*#Preview {
    ContentView()
}*/
